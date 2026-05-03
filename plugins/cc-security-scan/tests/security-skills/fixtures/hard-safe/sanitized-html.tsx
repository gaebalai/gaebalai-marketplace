// Fixture (Hard Safe): DOMPurify 로 새니타이즈 완료된 dangerouslySetInnerHTML
// dangerouslySetInnerHTML 을 사용하고 있지만, 안전

import React from "react";
import DOMPurify from "dompurify";

interface Props {
  richText: string; // CMS 에서 오는 리치 텍스트
}

// ✅ DOMPurify 로 새니타이즈한 후에 전달하고 있다 → 안전
export function RichTextDisplay({ richText }: Props) {
  const clean = DOMPurify.sanitize(richText, {
    ALLOWED_TAGS: ["b", "i", "em", "strong", "p", "br"],
    ALLOWED_ATTR: [],
  });

  return (
    <div
      className="rich-text"
      dangerouslySetInnerHTML={{ __html: clean }}
    />
  );
}
