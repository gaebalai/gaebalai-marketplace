// Fixture (Hard): 간접적인 XSS (헬퍼 함수 경유)
// dangerouslySetInnerHTML 을 직접 사용하고 있지 않은 것처럼 보이지만,
// 헬퍼 경유로 사용자 입력이 HTML 로서 삽입된다

import React from "react";

// 헬퍼 함수 (언뜻 무해해 보임)
function renderMarkdown(text: string): string {
  // **굵은 글씨** 를 <strong> 으로 변환
  let html = text.replace(/\*\*(.*?)\*\*/g, "<strong>$1</strong>");
  // [링크](url) 을 <a> 태그로 변환
  // ❌ href 에 사용자 입력이 들어간다 → javascript: 스킴이 통한다
  html = html.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');
  return html;
}

interface Props {
  comment: string; // 사용자가 입력한 값
}

// ❌ renderMarkdown 의 반환값을 dangerouslySetInnerHTML 에 전달하고 있다
// renderMarkdown 자체는 새니타이즈하지 않는다
export function CommentCard({ comment }: Props) {
  return (
    <div
      className="comment"
      dangerouslySetInnerHTML={{ __html: renderMarkdown(comment) }}
    />
  );
}
