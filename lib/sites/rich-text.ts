import "server-only";

import sanitizeHtml from "sanitize-html";

const allowedTags = ["p", "br", "strong", "em", "u", "ul", "ol", "li", "h2", "h3", "span"];

export function sanitizeSiteRichText(value: string) {
  return sanitizeHtml(value, {
    allowedTags,
    allowedAttributes: { span: ["style"] },
    allowedStyles: {
      "*": {
        color: [/^#[0-9a-f]{6}$/i],
        "font-size": [/^(12|14|16|18|20|24|28|32)px$/],
        "font-family": [/^(Arial|Georgia|Verdana|Trebuchet MS)$/],
      },
    },
    disallowedTagsMode: "discard",
  }).slice(0, 12000);
}
