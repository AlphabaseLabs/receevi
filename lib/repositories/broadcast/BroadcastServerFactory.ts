import { BroadcastRepository } from "./BroadcastRepository";
import { BroadcastRepositorySupabaseImpl } from "./BroadcastRepositorySupabaseImpl";
import { createClient as createServerClient } from "@/utils/supabase-server";

export default class BroadcastServerFactory {
    private static _instance: BroadcastRepository;
    public static async getInstance(): Promise<BroadcastRepository> {
        if (!BroadcastServerFactory._instance) {
            const client = await createServerClient();
            BroadcastServerFactory._instance = new BroadcastRepositorySupabaseImpl(client)
        }
        return BroadcastServerFactory._instance
    }
}
