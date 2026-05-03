// Fixture (Hard Safe): 사용자 입력이 전달되지 않는 exec
// exec 를 사용하고 있지만, 인수는 하드코딩 완료되어 있어 안전

import { exec } from "child_process";
import { promisify } from "util";

const execAsync = promisify(exec);

// ✅ 인수는 모두 하드코딩 (사용자 입력은 전달되지 않는다)
export async function runHealthCheck() {
  const { stdout } = await execAsync("node --version");
  return { nodeVersion: stdout.trim() };
}

// ✅ 사용자 입력은 숫자 밸리데이션 완료 후, 쿼리 파라미터에 전달할 뿐
export async function getReport(year: number, month: number) {
  if (!Number.isInteger(year) || !Number.isInteger(month)) {
    throw new Error("Invalid parameters");
  }
  // year 와 month 는 정수 체크 완료이기 때문에 인젝션 불가
  const { stdout } = await execAsync(`node scripts/generate-report.js ${year} ${month}`);
  return stdout;
}
