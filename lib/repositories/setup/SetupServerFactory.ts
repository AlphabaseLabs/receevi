import { createClient as createServerClient } from "@/utils/supabase-server";
import { SetupRepository } from "./SetupRepository";
import { SetupRepositorySupabaseImpl } from "./SetupRepositorySupabaseImpl";

export default class SetupServerFactory {
    private static _instance: SetupRepository;
    public static async getInstance(): Promise<SetupRepository> {
        if (!SetupServerFactory._instance) {
            const client = await createServerClient();
            SetupServerFactory._instance = new SetupRepositorySupabaseImpl(client)
        }
        return SetupServerFactory._instance
    }
}
