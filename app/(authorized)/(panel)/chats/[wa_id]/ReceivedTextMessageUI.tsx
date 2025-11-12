import { TextMessage } from "@/types/Message";
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';

export default function ReceivedTextMessageUI(props: { textMessage: TextMessage }) {
    const { textMessage } = props
    return (
        <div className="markdown-content">
            <ReactMarkdown
                remarkPlugins={[remarkGfm]}
                components={{
                    // Headings - more subtle sizing for chat context
                    h1: ({ node, ...props }) => <h1 className="text-base font-semibold mb-1 mt-2" {...props} />,
                    h2: ({ node, ...props }) => <h2 className="text-base font-semibold mb-1 mt-2" {...props} />,
                    h3: ({ node, ...props }) => <h3 className="text-base font-semibold mb-1 mt-1" {...props} />,
                    // Paragraphs
                    p: ({ node, ...props }) => <p className="mb-2 last:mb-0" {...props} />,
                    // Lists
                    ul: ({ node, ...props }) => <ul className="list-disc list-inside mb-2 space-y-0.5" {...props} />,
                    ol: ({ node, ...props }) => <ol className="list-decimal list-inside mb-2 space-y-0.5" {...props} />,
                    li: ({ node, ...props }) => <li className="ml-2" {...props} />,
                    // Code
                    code: ({ node, className, ...props }: any) => {
                        const isInline = !className?.includes('language-');
                        return isInline 
                            ? <code className="bg-black/10 px-1 py-0.5 rounded text-sm font-mono" {...props} />
                            : <code className="block bg-black/10 p-2 rounded text-sm font-mono overflow-x-auto my-2" {...props} />
                    },
                    pre: ({ node, ...props }) => <pre className="my-2" {...props} />,
                    // Links
                    a: ({ node, ...props }) => <a className="text-blue-600 underline hover:text-blue-800" target="_blank" rel="noopener noreferrer" {...props} />,
                    // Blockquotes
                    blockquote: ({ node, ...props }) => <blockquote className="border-l-4 border-gray-300 pl-3 italic my-2" {...props} />,
                    // Emphasis - using semibold instead of bold for more subtle look
                    strong: ({ node, ...props }) => <strong className="font-semibold" {...props} />,
                    em: ({ node, ...props }) => <em className="italic" {...props} />,
                    // Tables
                    table: ({ node, ...props }) => <table className="border-collapse w-full my-2 text-sm" {...props} />,
                    thead: ({ node, ...props }) => <thead className="bg-black/5" {...props} />,
                    th: ({ node, ...props }) => <th className="border border-gray-300 px-2 py-1 font-semibold" {...props} />,
                    td: ({ node, ...props }) => <td className="border border-gray-300 px-2 py-1" {...props} />,
                    // Horizontal rule
                    hr: ({ node, ...props }) => <hr className="my-3 border-t border-gray-300" {...props} />,
                }}
            >
                {textMessage.text.body}
            </ReactMarkdown>
        </div>
    )
}