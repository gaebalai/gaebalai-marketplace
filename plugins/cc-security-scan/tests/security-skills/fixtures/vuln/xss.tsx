// Fixture: XSS via dangerouslySetInnerHTML
// 의도적으로 취약한 코드 - 테스트용

import React from "react";

interface Props {
  userComment: string;  // 사용자가 입력한 값
}

// ❌ 사용자 입력을 그대로 innerHTML 에 전달
export function CommentDisplay({ userComment }: Props) {
  return (
    <div
      className="comment-body"
      dangerouslySetInnerHTML={{ __html: userComment }}
    />
  );
}

// ❌ eval 로 사용자 입력을 실행
export function runFormula(expression: string) {
  return eval(expression);
}
