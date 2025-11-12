import { ContactRepository } from "./ContactRepository";
import { ContactRepositorySupabaseImpl } from "./ContactRepositorySupabaseImpl";
import { createClient as createServerClient } from "@/utils/supabase-server";

export default class ContactServerFactory {
    private static _instance: ContactRepository;
    public static async getInstance(): Promise<ContactRepository> {
        if (!ContactServerFactory._instance) {
            const client = await createServerClient();
            ContactServerFactory._instance = new ContactRepositorySupabaseImpl(client)
        }
        return ContactServerFactory._instance
    }
}
