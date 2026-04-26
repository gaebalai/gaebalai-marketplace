import React from "react";
import { Composition } from "remotion";
import { Highlight60 } from "./Highlight60";
import { calculateMetadata } from "./calculateMetadata";
import type { HighlightProps } from "./types";

const defaultProps: HighlightProps = {
  title: "회의 하이라이트 (샘플)",
  meeting_date: "2025_12_04",
  totalDurationSec: 60,
  fps: 30,
  clips: [
    {
      id: 1,
      src: "clips/clip_1.mp4",
      topic: "샘플 토픽 1",
      caption: "샘플 자막 1",
      subCaption: "Phase 5 cut_clips.sh 실행 후 실제 클립이 채워집니다",
      sourceStartSec: 0,
      sourceEndSec: 15,
      durationSec: 15,
    },
    {
      id: 2,
      src: "clips/clip_2.mp4",
      topic: "샘플 토픽 2",
      caption: "샘플 자막 2",
      subCaption: "보조 자막 예시",
      sourceStartSec: 0,
      sourceEndSec: 15,
      durationSec: 15,
    },
    {
      id: 3,
      src: "clips/clip_3.mp4",
      topic: "샘플 토픽 3",
      caption: "샘플 자막 3",
      subCaption: "보조 자막 예시",
      sourceStartSec: 0,
      sourceEndSec: 15,
      durationSec: 15,
    },
    {
      id: 4,
      src: "clips/clip_4.mp4",
      topic: "샘플 토픽 4",
      caption: "샘플 자막 4",
      subCaption: "보조 자막 예시",
      sourceStartSec: 0,
      sourceEndSec: 15,
      durationSec: 15,
    },
  ],
};

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="Highlight60"
      component={Highlight60}
      width={1920}
      height={1080}
      fps={30}
      durationInFrames={60 * 30}
      defaultProps={defaultProps}
      calculateMetadata={calculateMetadata}
    />
  );
};
