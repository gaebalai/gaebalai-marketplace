import React, { useState } from "react";

interface Feedback {
  id: string;
  author: string;
  content: string;
}

export function FeedbackList({ items }: { items: Feedback[] }) {
  return (
    <ul>
      {items.map((item) => (
        <li key={item.id}>
          <strong>{item.author}</strong>
          <span dangerouslySetInnerHTML={{ __html: item.content }} />
        </li>
      ))}
    </ul>
  );
}
