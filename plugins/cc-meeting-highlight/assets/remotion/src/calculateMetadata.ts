import type { CalculateMetadataFunction } from "remotion";
import type { HighlightProps } from "./types";

export const calculateMetadata: CalculateMetadataFunction<HighlightProps> = ({
  props,
}) => {
  const fps = props.fps ?? 30;
  const totalSec =
    props.totalDurationSec ??
    props.clips.reduce((acc, c) => acc + c.durationSec, 0);

  return {
    fps,
    durationInFrames: Math.round(totalSec * fps),
    width: 1920,
    height: 1080,
  };
};
