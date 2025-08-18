'use client'

import { useEffect, useState } from "react";
import { useSupabase } from "@/components/supabase-provider";

export default function ReceivedAudioMessageUI({ message }: { message: DBMessage }) {
    const { supabase } = useSupabase()
    const [audioUrl, setAudioUrl] = useState<string | null>(null);

    useEffect(() => {
        if (message.media_url) {
            supabase
                .storage
                .from('media')
                .createSignedUrl(message.media_url, 60)
                .then(({ data, error }) => {
                    if (error) throw error
                    setAudioUrl(data.signedUrl)
                })
                .catch(e => console.error(e))
        }
    }, [supabase.storage, message.media_url])

    return (
        <div className="bg-[#00000011] p-3 rounded-md flex flex-col gap-3 min-w-[200px]">
            <audio 
                className="w-full" 
                controls 
                controlsList="nodownload nofullscreen noremoteplayback"
                src={audioUrl || ''} 
                preload="metadata"
            />
        </div>
    )
}