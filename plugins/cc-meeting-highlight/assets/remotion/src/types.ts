export type Clip = {
  id: number;
  src: string;
  topic?: string;
  caption: string;
  subCaption?: string;
  sourceStartSec: number;
  sourceEndSec: number;
  durationSec: number;
  speakers?: string[];
};

export type HighlightProps = {
  title: string;
  meeting_date?: string;
  totalDurationSec: number;
  fps: number;
  clips: Clip[];
};
