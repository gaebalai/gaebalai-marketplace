// car-noise-pwa-builder generated client
// {{PROJECT_NAME}}

const PI_HOST = window.PI_HOST;
const MAPPING = window.SIGNAL_MAPPING || {};

// ---------- DOM ----------
const $ = (id) => document.getElementById(id);
const specCv = $("spec");
const fftCv = $("fft");
const specCtx = specCv.getContext("2d");
const fftCtx = fftCv.getContext("2d");

function fitCanvas(cv) {
  const r = cv.getBoundingClientRect();
  cv.width = r.width * devicePixelRatio;
  cv.height = r.height * devicePixelRatio;
}
addEventListener("resize", () => { fitCanvas(specCv); fitCanvas(fftCv); });
fitCanvas(specCv); fitCanvas(fftCv);

// ---------- Audio ----------
let audioCtx, analyser, mediaStream, recorder, chunks = [];
let recording = false;
let canLog = []; // [{t, rpm, speed, steering, gear}]
const startTimes = { audio: null };

async function startMic() {
  if (audioCtx) return;
  audioCtx = new AudioContext();
  mediaStream = await navigator.mediaDevices.getUserMedia({ audio: { echoCancellation: false, noiseSuppression: false } });
  const src = audioCtx.createMediaStreamSource(mediaStream);
  analyser = audioCtx.createAnalyser();
  analyser.fftSize = 16384;
  analyser.smoothingTimeConstant = 0.6;
  src.connect(analyser);
  drawLoop();
}

const FREQ_MAX = 500; // Hz — 차량 저음 영역 강조
function drawLoop() {
  const bins = analyser.frequencyBinCount;
  const data = new Uint8Array(bins);
  analyser.getByteFrequencyData(data);
  const nyquist = audioCtx.sampleRate / 2;
  const cutBin = Math.min(bins, Math.floor((FREQ_MAX / nyquist) * bins));

  // FFT 스펙트럼
  fftCtx.fillStyle = "#000";
  fftCtx.fillRect(0, 0, fftCv.width, fftCv.height);
  fftCtx.strokeStyle = "#3498db";
  fftCtx.beginPath();
  let peakBin = 0, peakVal = 0;
  for (let i = 0; i < cutBin; i++) {
    const x = (i / cutBin) * fftCv.width;
    const y = fftCv.height - (data[i] / 255) * fftCv.height;
    if (i === 0) fftCtx.moveTo(x, y); else fftCtx.lineTo(x, y);
    if (data[i] > peakVal) { peakVal = data[i]; peakBin = i; }
  }
  fftCtx.stroke();
  $("peak").textContent = `${Math.round((peakBin / bins) * nyquist)} Hz`;

  // 스펙트로그램 — 한 컬럼씩 좌측으로 시프트
  const w = specCv.width, h = specCv.height;
  const img = specCtx.getImageData(1, 0, w - 1, h);
  specCtx.putImageData(img, 0, 0);
  for (let y = 0; y < h; y++) {
    const bin = Math.floor(((h - y) / h) * cutBin);
    const v = data[bin] || 0;
    specCtx.fillStyle = magma(v);
    specCtx.fillRect(w - 1, y, 1, 1);
  }

  requestAnimationFrame(drawLoop);
}

function magma(v) {
  // 0..255 → magma-ish
  const t = v / 255;
  const r = Math.min(255, Math.floor(255 * Math.pow(t, 0.5)));
  const g = Math.min(255, Math.floor(255 * Math.pow(t, 1.8)));
  const b = Math.min(255, Math.floor(255 * Math.pow(1 - t, 2) + 60 * t));
  return `rgb(${r},${g},${b})`;
}

// ---------- WebSocket → CAN ----------
let ws;
function connectWS() {
  const url = `wss://${PI_HOST}:8443/ws`;
  ws = new WebSocket(url);
  ws.onopen = () => $("wsStatus").textContent = "WS:OK";
  ws.onclose = () => { $("wsStatus").textContent = "WS:끊김"; setTimeout(connectWS, 2000); };
  ws.onerror = () => $("wsStatus").textContent = "WS:오류";
  ws.onmessage = (e) => {
    const msg = JSON.parse(e.data); // {t, rpm, speed, steering, gear}
    if (msg.rpm != null) $("rpm").textContent = Math.round(msg.rpm);
    if (msg.speed != null) $("speed").textContent = `${msg.speed.toFixed(1)} km/h`;
    if (msg.steering != null) $("steering").textContent = `${msg.steering.toFixed(0)}°`;
    if (msg.gear != null) $("gear").textContent = msg.gear;
    if (recording) canLog.push(msg);
  };
}
connectWS();

// ---------- Recording ----------
$("btnRec").onclick = async () => {
  await startMic();
  if (!recording) {
    chunks = []; canLog = [];
    recorder = new MediaRecorder(mediaStream, { mimeType: "audio/webm" });
    recorder.ondataavailable = (e) => e.data.size && chunks.push(e.data);
    recorder.start(250);
    startTimes.audio = Date.now();
    recording = true;
    $("btnRec").textContent = "■ 정지";
    $("btnRec").classList.add("rec");
    $("status").textContent = "녹음중";
  } else {
    recorder.stop();
    recording = false;
    $("btnRec").textContent = "● 녹음";
    $("btnRec").classList.remove("rec");
    $("status").textContent = "정지";
    await persistTake();
  }
};

// ---------- IndexedDB ----------
const dbReady = new Promise((resolve, reject) => {
  const req = indexedDB.open("car-noise-takes", 1);
  req.onupgradeneeded = () => req.result.createObjectStore("takes", { keyPath: "id", autoIncrement: true });
  req.onsuccess = () => resolve(req.result);
  req.onerror = () => reject(req.error);
});

async function persistTake() {
  await new Promise(r => recorder.onstop = r);
  const blob = new Blob(chunks, { type: "audio/webm" });
  const take = { ts: Date.now(), audio: blob, can: canLog };
  const db = await dbReady;
  await new Promise((resolve, reject) => {
    const tx = db.transaction("takes", "readwrite");
    tx.objectStore("takes").add(take).onsuccess = resolve;
    tx.onerror = () => reject(tx.error);
  });
  $("status").textContent = `저장됨 (${(blob.size/1024).toFixed(0)} KB)`;
}

// ---------- ZIP export ----------
$("btnExport").onclick = async () => {
  const db = await dbReady;
  const takes = await new Promise((res) => {
    const tx = db.transaction("takes", "readonly");
    const r = tx.objectStore("takes").getAll();
    r.onsuccess = () => res(r.result);
  });
  if (!takes.length) return alert("저장된 녹음이 없습니다");
  const zip = new JSZip();
  takes.forEach((t, i) => {
    const folder = zip.folder(`take_${String(i+1).padStart(3,"0")}_${t.ts}`);
    folder.file("audio.webm", t.audio);
    const csv = ["t,rpm,speed,steering,gear", ...t.can.map(c =>
      `${c.t},${c.rpm ?? ""},${c.speed ?? ""},${c.steering ?? ""},${c.gear ?? ""}`)].join("\n");
    folder.file("can.csv", csv);
    folder.file("metadata.json", JSON.stringify({ ts: t.ts, mapping: MAPPING }, null, 2));
  });
  const blob = await zip.generateAsync({ type: "blob" });
  const url = URL.createObjectURL(blob);
  const a = Object.assign(document.createElement("a"),
    { href: url, download: `car-noise-takes-${Date.now()}.zip` });
  a.click(); URL.revokeObjectURL(url);
};
