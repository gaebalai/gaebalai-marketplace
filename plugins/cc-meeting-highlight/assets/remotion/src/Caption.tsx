import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame, useVideoConfig } from "remotion";

type Props = {
  caption: string;
  subCaption?: string;
};

export const Caption: React.FC<Props> = ({ caption, subCaption }) => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();

  const fadeFrames = Math.round(fps * 0.25);
  const fadeIn = interpolate(frame, [0, fadeFrames], [0, 1], {
    extrapolateRight: "clamp",
  });
  const fadeOut = interpolate(
    frame,
    [durationInFrames - fadeFrames, durationInFrames],
    [1, 0],
    { extrapolateLeft: "clamp" }
  );
  const opacity = Math.min(fadeIn, fadeOut);

  return (
    <AbsoluteFill
      style={{
        justifyContent: "flex-end",
        alignItems: "center",
        paddingBottom: 96,
        opacity,
      }}
    >
      <div
        style={{
          maxWidth: "85%",
          padding: "20px 40px",
          background: "rgba(0,0,0,0.78)",
          borderRadius: 16,
          textAlign: "center",
          backdropFilter: "blur(8px)",
        }}
      >
        <div
          style={{
            color: "white",
            fontSize: 64,
            fontWeight: 800,
            lineHeight: 1.25,
            letterSpacing: "-0.02em",
            wordBreak: "keep-all",
          }}
        >
          {caption}
        </div>
        {subCaption ? (
          <div
            style={{
              marginTop: 12,
              color: "rgba(255,255,255,0.85)",
              fontSize: 32,
              fontWeight: 500,
              lineHeight: 1.3,
              wordBreak: "keep-all",
            }}
          >
            {subCaption}
          </div>
        ) : null}
      </div>
    </AbsoluteFill>
  );
};
