import { ContactTagRepository } from "./ContactTagRepository";
import { ContactTagRepositorySupabaseImpl } from "./ContactTagRepositorySupabaseImpl";
import { createClient as createServerClient } from "@/utils/supabase-server";

export default class ContactTagServerFactory {
    private static _instance: ContactTagRepository;
    public static async getInstance(): Promise<ContactTagRepository> {
        if (!ContactTagServerFactory._instance) {
            const client = await createServerClient();
            ContactTagServerFactory._instance = new ContactTagRepositorySupabaseImpl(client)
        }
        return ContactTagServerFactory._instance
    }
}
