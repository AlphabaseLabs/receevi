export type MessageTemplateResponse = {
    data: MessageTemplate[];
    paging: WhatsappPaging
}

export type WhatsappPaging = {
    cursors: {
        before: string;
        after: string;
    }
}

export type MessageTemplate = {
    name: string;
    previous_category?: string | null;
    components: MessageTemplateComponent[];
    language: string;
    status: string;
    category: string;
    id: string;
    // Add support for interactive messages
    interactive?: InteractiveMessage;
    // Add support for interactive text messages
    text?: any; // This can be a string or an object with more details
};

export type MessageTemplateComponent =
    | MessageTemplateHeader
    | MessageTemplateBody
    | MessageTemplateFooter
    | MessageTemplateButtons;

export type MessageTemplateHeader = {
    type: "HEADER";
} & (
    {
        format: "TEXT";
        text: string;
        example?: {
            header_text?: string[];
        }
    } |
    {
        format: "IMAGE";
        image?: {
            link: string
        },
        example?: {
            header_handle: string[];
        };
    } |
    {
        format: "VIDEO";
        video?: {
            link: string
        },
        example?: {
            header_handle: string[];
        };
    } |
    {
        format: "DOCUMENT";
        document?: {
            link: string
        },
        example?: {
            header_handle: string[];
        };
    }
);

export type MessageTemplateBody = {
    type: "BODY";
    text: string;
    example?: {
        body_text: string[][];
    };
};

export type MessageTemplateFooter = {
    type: "FOOTER";
    text: string;
};

export type MessageTemplateButtons = {
    type: "BUTTONS";
    buttons: MessageTemplateButton[];
};

export type MessageTemplateButton = {
    example?: string[]
    text: string
} & ({
    type: "QUICK_REPLY" | "PHONE_NUMBER" | "COPY_CODE"
} | {
    type: "URL"
    url: string
});

// Add new types for interactive messages
export type InteractiveMessage = {
    type: 'list' | 'button' | 'product' | 'product_list';
    body?: {
        text: string;
    };
    action: {
        button?: string;
        sections?: InteractiveSection[];
        buttons?: InteractiveButton[];
    };
    messaging_product: string;
};

export type InteractiveSection = {
    title: string;
    rows: InteractiveRow[];
};

export type InteractiveRow = {
    id: string;
    title: string;
    description?: string;
};

export type InteractiveButton = {
    type: 'reply';
    reply: {
        id: string;
        title: string;
    };
};
