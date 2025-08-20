import { InteractiveMessage } from "@/types/Message"

export default function ReceivedInteractiveMessageUI({ message }: { message: InteractiveMessage }) {
    // Handle button messages (type: "button")
    if (message.button) {
        return (
            <div className="max-w-sm">
                <div className="flex items-center gap-2 p-2 bg-gray-50 rounded-lg border border-gray-200">
                    <span className="text-sm font-medium text-gray-900">
                        {message.button.text}
                    </span>
                </div>
            </div>
        )
    }

    // Handle interactive messages (type: "interactive")
    if (message.interactive) {
        const { interactive } = message

        const renderInteractiveContent = () => {
            switch (interactive.type) {
                case 'list_reply':
                    if (interactive.list_reply) {
                        return (
                            <div className="flex items-center gap-2 p-2 bg-gray-50 rounded-lg border border-gray-200">
                                <span className="text-sm font-medium text-gray-900">
                                    {interactive.list_reply.title}
                                </span>
                            </div>
                        )
                    }
                    break
                case 'button_reply':
                    if (interactive.button_reply) {
                        return (
                            <div className="flex items-center gap-2 p-2 bg-gray-50 rounded-lg border border-gray-200">
                                <span className="text-sm font-medium text-gray-900">
                                    {interactive.button_reply.title}
                                </span>
                            </div>
                        )
                    }
                    break
                default:
                    return (
                        <div className="p-2 bg-gray-50 rounded-lg border border-gray-200">
                            <span className="text-sm text-gray-600">
                                Interactive message: {interactive.type}
                            </span>
                        </div>
                    )
            }
            return null
        }

        return (
            <div className="max-w-sm">
                {renderInteractiveContent()}
            </div>
        )
    }

    // Fallback for unknown message types
    return (
        <div className="max-w-sm">
            <div className="p-2 bg-gray-50 rounded-lg border border-gray-200">
                <span className="text-sm text-gray-600">
                    Unknown message format
                </span>
            </div>
        </div>
    )
}
