import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import type { Components } from 'react-markdown';

const components: Components = {
  h1: ({ children, ...props }) => (
    <h1 className="mb-4 mt-10 scroll-mt-20 text-2xl font-bold tracking-tight text-foreground first:mt-0" {...props}>
      {children}
    </h1>
  ),
  h2: ({ children, ...props }) => (
    <h2 className="mb-3 mt-9 scroll-mt-20 text-xl font-semibold tracking-tight text-foreground" {...props}>
      {children}
    </h2>
  ),
  h3: ({ children, ...props }) => (
    <h3 className="mb-2 mt-7 text-lg font-semibold text-foreground" {...props}>
      {children}
    </h3>
  ),
  p: ({ children, ...props }) => (
    <p className="mb-4 text-sm leading-relaxed text-foreground/90" {...props}>
      {children}
    </p>
  ),
  ul: ({ children, ...props }) => (
    <ul className="mb-4 list-disc space-y-1.5 pl-5 text-sm leading-relaxed text-foreground/90" {...props}>
      {children}
    </ul>
  ),
  ol: ({ children, ...props }) => (
    <ol className="mb-4 list-decimal space-y-1.5 pl-5 text-sm leading-relaxed text-foreground/90" {...props}>
      {children}
    </ol>
  ),
  li: ({ children, ...props }) => (
    <li className="marker:text-muted-foreground" {...props}>
      {children}
    </li>
  ),
  a: ({ children, href, ...props }) => (
    <a
      href={href}
      className="font-medium text-primary underline-offset-4 hover:underline"
      rel="noopener noreferrer"
      {...props}
    >
      {children}
    </a>
  ),
  blockquote: ({ children, ...props }) => (
    <blockquote
      className="mb-4 border-l-4 border-primary/35 bg-muted/40 px-4 py-3 text-sm text-muted-foreground"
      {...props}
    >
      {children}
    </blockquote>
  ),
  hr: (props) => <hr className="my-8 border-border/80" {...props} />,
  table: ({ children, ...props }) => (
    <div className="mb-4 overflow-x-auto rounded-lg border border-border/80">
      <table className="w-full min-w-[520px] border-collapse text-left text-sm" {...props}>
        {children}
      </table>
    </div>
  ),
  thead: ({ children, ...props }) => <thead className="bg-muted/50 text-foreground" {...props}>{children}</thead>,
  th: ({ children, ...props }) => (
    <th className="border-b border-border/80 px-3 py-2 font-semibold" {...props}>
      {children}
    </th>
  ),
  td: ({ children, ...props }) => (
    <td className="border-b border-border/60 px-3 py-2 align-top text-foreground/90" {...props}>
      {children}
    </td>
  ),
  tr: ({ children, ...props }) => <tr className="last:[&>td]:border-b-0" {...props}>{children}</tr>,
  code: ({ className, children, ...props }) => {
    const isFenced = Boolean(className?.startsWith('language-'));
    if (isFenced) {
      return (
        <code className={className} {...props}>
          {children}
        </code>
      );
    }
    return (
      <code className="rounded bg-muted/80 px-1 py-0.5 font-mono text-[0.85em]" {...props}>
        {children}
      </code>
    );
  },
  pre: ({ children, ...props }) => (
    <pre className="mb-4 overflow-x-auto rounded-lg border border-border/60 bg-muted/50 p-3 text-xs leading-relaxed" {...props}>
      {children}
    </pre>
  ),
  strong: ({ children, ...props }) => (
    <strong className="font-semibold text-foreground" {...props}>
      {children}
    </strong>
  ),
};

export function LegalMarkdown({ source }: { source: string }) {
  return (
    <article className="legal-markdown text-foreground">
      <ReactMarkdown remarkPlugins={[remarkGfm]} components={components}>
        {source}
      </ReactMarkdown>
    </article>
  );
}
