'use client'

import { useEffect, useState } from "react";
import { useSupabase } from "@/components/supabase-provider";
import { PlayIcon, PauseIcon } from "lucide-react";

export default function ReceivedAudioMessageUI({ message }: { message: DBMessage }) {
    const { supabase } = useSupabase()
    const [audioUrl, setAudioUrl] = useState<string | null>(null);
    const [isPlaying, setIsPlaying] = useState(false);
    const [audioElement, setAudioElement] = useState<HTMLAudioElement | null>(null);

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
    }, [supabase.storage, message.media_url, setAudioUrl])

    const togglePlayPause = () => {
        if (!audioElement) return;
        
        if (isPlaying) {
            audioElement.pause();
            setIsPlaying(false);
        } else {
            audioElement.play();
            setIsPlaying(true);
        }
    };

    useEffect(() => {
        if (audioUrl) {
            const audio = new Audio(audioUrl);
            audio.addEventListener('ended', () => setIsPlaying(false));
            setAudioElement(audio);
            
            return () => {
                audio.removeEventListener('ended', () => setIsPlaying(false));
            };
        }
    }, [audioUrl]);

    return (
        <div className="bg-[#00000011] p-3 rounded-md flex flex-row items-center gap-3 min-w-[200px]">
            <button 
                onClick={togglePlayPause}
                className="w-8 h-8 rounded-full bg-blue-500 flex items-center justify-center text-white hover:bg-blue-600 transition-colors"
            >
                {isPlaying ? <PauseIcon size={16} /> : <PlayIcon size={16} />}
            </button>
            <div className="flex-1">
                <div className="text-sm font-medium">Audio Message</div>
                <div className="text-xs text-gray-500">Tap to play/pause</div>
            </div>
        </div>
    )
}