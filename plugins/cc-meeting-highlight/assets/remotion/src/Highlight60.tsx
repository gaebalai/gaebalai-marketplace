import React from "react";
import { AbsoluteFill, OffthreadVideo, Series, staticFile } from "remotion";
import { loadFont } from "@remotion/google-fonts/NotoSansKR";
import { Caption } from "./Caption";
import type { HighlightProps } from "./types";

const { fontFamily } = loadFont("normal", {
  weights: ["400", "500", "700", "800"],
});

export const Highlight60: React.FC<HighlightProps> = ({ clips, fps }) => {
  const frameRate = fps ?? 30;

  return (
    <AbsoluteFill style={{ background: "black", fontFamily }}>
      <Series>
        {clips.map((clip) => {
          const frames = Math.max(1, Math.round(clip.durationSec * frameRate));
          return (
            <Series.Sequence key={clip.id} durationInFrames={frames}>
              <AbsoluteFill>
                <OffthreadVideo
                  src={staticFile(clip.src)}
                  muted={false}
                  style={{
                    width: "100%",
                    height: "100%",
                    objectFit: "cover",
                  }}
                />
              </AbsoluteFill>
              <Caption caption={clip.caption} subCaption={clip.subCaption} />
            </Series.Sequence>
          );
        })}
      </Series>
    </AbsoluteFill>
  );
};
