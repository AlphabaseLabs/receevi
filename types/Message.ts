import { MessageTemplate } from "./message-template"

export type MessageJson = {
    from?: string,
    to?: string,
    id: string,
    timestamp: string,
    type: string,
}

export type TextMessageBody = {
    body: string,
}

export type TextMessage = MessageJson & {
    text: TextMessageBody
}

export type ImageMessageBody = {
    mime_type: string,
    sha256: string,
    id: string,
}

export type TemplateMessage = MessageJson & {
    template: MessageTemplate
}

export type ImageMessage = MessageJson & {
    image: ImageMessageBody,
}

export type InteractiveMessage = MessageJson & {
    context?: {
        id: string,
        from: string
    },
    interactive?: {
        type: 'list_reply' | 'button_reply' | 'product' | 'product_list',
        list_reply?: {
            id: string,
            title: string
        },
        button_reply?: {
            id: string,
            title: string
        }
    },
    button?: {
        text: string,
        payload: string
    }
}
