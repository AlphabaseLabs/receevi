import { TemplateMessage } from "@/types/Message";
import { MessageTemplateBody, MessageTemplateButtons, MessageTemplateFooter, MessageTemplateHeader, InteractiveSection, InteractiveRow } from "@/types/message-template";
import { CopyIcon, DownloadIcon, FileIcon, PhoneIcon, ReplyIcon, SquareArrowOutUpRightIcon } from "lucide-react";

function MessageTemplateHeaderComp(props: { component: MessageTemplateHeader }) {
    switch (props.component.format) {
        case "TEXT":
            return (
                <div className="font-medium pb-2">{props.component.text}</div>
            )
        case "DOCUMENT":
            const actualDocumentLink = props.component.document?.link
            const documentLinkToView = actualDocumentLink || props.component.example?.header_handle && props.component.example?.header_handle[0] || ''
            return (
                <div className="bg-[#00000011] p-2 rounded-md flex flex-row  items-center justify-between">
                    <div className="flex flex-row items-center gap-2">
                        <FileIcon />
                        <span>Example document</span>
                    </div>
                    <a href={documentLinkToView} target="_blank"><DownloadIcon /></a>
                </div>
            )
        case "IMAGE":
            const actualImageLink = props.component.image?.link
            const imageLinkToView = actualImageLink || props.component.example?.header_handle && props.component.example?.header_handle[0] || ''
            return (
                <div className="font-medium pb-2">
                    <img className="h-32 object-cover w-full" src={imageLinkToView} />
                </div>
            )
        case "VIDEO":
            const actualVideoLink = props.component.video?.link
            const videoLinkToView = actualVideoLink || props.component.example?.header_handle && props.component.example?.header_handle[0] || ''
            return (
                <div className="font-medium pb-2">
                    <video className="h-32 object-cover w-full" controls src={videoLinkToView || ''} />
                </div>
            )
        default:
            return;
    }
}

function MessageTemplateBodyComp(props: { component: MessageTemplateBody }) {
    return (
        <div>{props.component.text}</div>
    )
}

function MessageTemplateFooterComp(props: { component: MessageTemplateFooter }) {
    return (
        <div className="pt-2">
            <span className="text-gray-500">{props.component.text}</span>
        </div>
    )
}

function MessageTemplateButtonsComp(props: { component: MessageTemplateButtons }) {
    if (props.component.buttons.length > 0) {
        return (
            <>
                <div>
                    {(() => {
                        return props.component.buttons.map((button, index) => {
                            return (
                                <div key={index}>
                                    <div className="border-t border-b-0 my-2 border-slate-300"></div>
                                    <div className="flex flex-row items-center gap-2 justify-center p-1">
                                        {(() => {
                                            if (button.type === "URL") {
                                                return (
                                                    <div className="cursor-pointer flex flex-row items-center">
                                                        <SquareArrowOutUpRightIcon className="w-4 h-4 text-[#00a5f4] inline-block" />
                                                        &nbsp;&nbsp;
                                                        <a className="text-[#00a5f4] text-center" target="_blank" rel="noopener noreferrer" href={button.url}>{button.text}</a>
                                                    </div>
                                                )
                                            } else if (button.type === "PHONE_NUMBER") {
                                                return (
                                                    <div className="cursor-pointer flex flex-row items-center">
                                                        <PhoneIcon className="w-4 h-4 text-[#00a5f4] inline-block" />
                                                        &nbsp;&nbsp;
                                                        <span className="text-[#00a5f4]">{button.text}</span>
                                                    </div>
                                                )
                                            } else if (button.type === "QUICK_REPLY") {
                                                return (
                                                    <div className="cursor-pointer flex flex-row items-center">
                                                        <ReplyIcon className="w-4 h-4 text-[#00a5f4] inline-block" />
                                                        &nbsp;&nbsp;
                                                        <span className="text-[#00a5f4]">{button.text}</span>
                                                    </div>
                                                )
                                            } else if (button.type === "COPY_CODE") {
                                                return (
                                                    <div className="cursor-pointer flex flex-row items-center">
                                                        <CopyIcon className="w-4 h-4 text-[#00a5f4] inline-block" />
                                                        &nbsp;&nbsp;
                                                        <span className="text-[#00a5f4]">{button.text}</span>
                                                    </div>
                                                )
                                            } else {
                                                return <span className="text-[#00a5f4] cursor-pointer">{button.text}</span>
                                            }
                                        })()}
                                    </div>
                                </div>
                            )
                        })
                    })()}
                </div>
            </>
        )
    }
}

export default function ReceivedTemplateMessageUI(props: { message: TemplateMessage }) {
    // Check if the message has the traditional components structure
    if (props.message.template.components && props.message.template.components.length > 0) {
        return (
            <div className="max-w-sm">
                {props.message.template.components.map((component, index) => {
                    switch (component.type) {
                        case 'HEADER':
                            return <MessageTemplateHeaderComp key={index} component={component} />
                        case 'BODY':
                            return <MessageTemplateBodyComp key={index} component={component} />
                        case 'FOOTER':
                            return <MessageTemplateFooterComp key={index} component={component} />
                        case 'BUTTONS':
                            return <MessageTemplateButtonsComp key={index} component={component} />
                        default:
                            return null;
                    }
                })}
            </div>
        )
    }

    // Handle interactive template messages (like the example provided)
    if (props.message.template.interactive) {
        const interactive = props.message.template.interactive;
        
        return (
            <div className="max-w-sm">
                {/* Interactive Body */}
                {interactive.body && (
                    <div className="pb-2">
                        {interactive.body.text}
                    </div>
                )}
                
                {/* Interactive Action */}
                {interactive.action && (
                    <div className="border-t border-slate-300 pt-2">
                        {interactive.action.button && (
                            <div className="text-center text-[#00a5f4] font-medium mb-2">
                                {interactive.action.button}
                            </div>
                        )}
                        
                        {/* Handle List Type */}
                        {interactive.type === 'list' && interactive.action.sections && (
                            <div className="space-y-2">
                                {interactive.action.sections.map((section: InteractiveSection, sectionIndex: number) => (
                                    <div key={sectionIndex}>
                                        {section.title && (
                                            <div className="font-medium text-sm text-gray-700 mb-1">
                                                {section.title}
                                            </div>
                                        )}
                                        {section.rows && (
                                            <div className="space-y-1">
                                                {section.rows.map((row: InteractiveRow, rowIndex: number) => (
                                                    <div key={rowIndex} className="text-sm text-gray-600">
                                                        {row.title}
                                                    </div>
                                                ))}
                                            </div>
                                        )}
                                    </div>
                                ))}
                            </div>
                        )}
                        
                    </div>
                )}
            </div>
        )
    }

    // ✅ Handle simple template with text body
    if (props.message.template.text && props.message.template.text.body) {
        return (
            <div className="max-w-sm">
                <div className="p-2">
                    {props.message.template.text.body}
                </div>
            </div>
        )
    }

    // Fallback for unrecognized template structure
    return (
        <div className="max-w-sm text-gray-500 text-sm">
            Template message (format not recognized)
        </div>
    )
}