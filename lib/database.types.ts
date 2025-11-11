export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "13.0.5"
  }
  public: {
    Tables: {
      appointment_reminders: {
        Row: {
          appointment_uuid: string | null
          cancel_by: string | null
          contact_id: number
          created_at: string
          id: string
          patient_response: string | null
          send_by: string
          status: string
          template_id: string
          updated_at: string
        }
        Insert: {
          appointment_uuid?: string | null
          cancel_by?: string | null
          contact_id: number
          created_at?: string
          id?: string
          patient_response?: string | null
          send_by: string
          status: string
          template_id: string
          updated_at?: string
        }
        Update: {
          appointment_uuid?: string | null
          cancel_by?: string | null
          contact_id?: number
          created_at?: string
          id?: string
          patient_response?: string | null
          send_by?: string
          status?: string
          template_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "appointment_reminders_contact_id_fkey"
            columns: ["contact_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
        ]
      }
      bot_intents: {
        Row: {
          active: boolean
          created_at: string
          definition: Json
          id: string
          is_regex: boolean
          key: string
          kind: string
          locale: string | null
          name: string
          phrase: string
          priority: number
          tenant_id: string
          voided: boolean
        }
        Insert: {
          active?: boolean
          created_at?: string
          definition?: Json
          id?: string
          is_regex?: boolean
          key: string
          kind?: string
          locale?: string | null
          name: string
          phrase: string
          priority?: number
          tenant_id: string
          voided?: boolean
        }
        Update: {
          active?: boolean
          created_at?: string
          definition?: Json
          id?: string
          is_regex?: boolean
          key?: string
          kind?: string
          locale?: string | null
          name?: string
          phrase?: string
          priority?: number
          tenant_id?: string
          voided?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "bot_intents_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      broadcast: {
        Row: {
          contact_tags: string[] | null
          created_at: string
          delivered_count: number
          failed_count: number
          id: string
          language: string
          name: string
          processed_count: number
          read_count: number
          replied_count: number
          scheduled_count: number | null
          sent_count: number
          template_name: string
        }
        Insert: {
          contact_tags?: string[] | null
          created_at?: string
          delivered_count?: number
          failed_count?: number
          id?: string
          language: string
          name: string
          processed_count?: number
          read_count?: number
          replied_count?: number
          scheduled_count?: number | null
          sent_count?: number
          template_name: string
        }
        Update: {
          contact_tags?: string[] | null
          created_at?: string
          delivered_count?: number
          failed_count?: number
          id?: string
          language?: string
          name?: string
          processed_count?: number
          read_count?: number
          replied_count?: number
          scheduled_count?: number | null
          sent_count?: number
          template_name?: string
        }
        Relationships: []
      }
      broadcast_batch: {
        Row: {
          broadcast_id: string
          created_at: string
          ended_at: string | null
          id: string
          scheduled_count: number
          sent_count: number
          started_at: string | null
          status: string | null
        }
        Insert: {
          broadcast_id: string
          created_at?: string
          ended_at?: string | null
          id: string
          scheduled_count: number
          sent_count?: number
          started_at?: string | null
          status?: string | null
        }
        Update: {
          broadcast_id?: string
          created_at?: string
          ended_at?: string | null
          id?: string
          scheduled_count?: number
          sent_count?: number
          started_at?: string | null
          status?: string | null
        }
        Relationships: []
      }
      broadcast_contact: {
        Row: {
          batch_id: string
          broadcast_id: string
          contact_id: number
          created_at: string
          delivered_at: string | null
          failed_at: string | null
          id: string
          processed_at: string | null
          read_at: string | null
          replied_at: string | null
          reply_counted: boolean
          sent_at: string | null
          wam_id: string | null
        }
        Insert: {
          batch_id: string
          broadcast_id: string
          contact_id: number
          created_at?: string
          delivered_at?: string | null
          failed_at?: string | null
          id?: string
          processed_at?: string | null
          read_at?: string | null
          replied_at?: string | null
          reply_counted?: boolean
          sent_at?: string | null
          wam_id?: string | null
        }
        Update: {
          batch_id?: string
          broadcast_id?: string
          contact_id?: number
          created_at?: string
          delivered_at?: string | null
          failed_at?: string | null
          id?: string
          processed_at?: string | null
          read_at?: string | null
          replied_at?: string | null
          reply_counted?: boolean
          sent_at?: string | null
          wam_id?: string | null
        }
        Relationships: []
      }
      contact_tag: {
        Row: {
          created_at: string
          id: string
          name: string
        }
        Insert: {
          created_at?: string
          id?: string
          name: string
        }
        Update: {
          created_at?: string
          id?: string
          name?: string
        }
        Relationships: []
      }
      contacts: {
        Row: {
          assigned_to: string | null
          created_at: string
          id: number
          in_chat: boolean
          last_message_at: string | null
          last_message_received_at: string | null
          opted_out: boolean
          phone_number_id: string | null
          profile_name: string | null
          tags: string[]
          tenant_id: string
          unread_count: number
          voided: boolean
          wa_id: string
        }
        Insert: {
          assigned_to?: string | null
          created_at?: string
          id?: number
          in_chat?: boolean
          last_message_at?: string | null
          last_message_received_at?: string | null
          opted_out?: boolean
          phone_number_id?: string | null
          profile_name?: string | null
          tags?: string[]
          tenant_id: string
          unread_count?: number
          voided?: boolean
          wa_id: string
        }
        Update: {
          assigned_to?: string | null
          created_at?: string
          id?: number
          in_chat?: boolean
          last_message_at?: string | null
          last_message_received_at?: string | null
          opted_out?: boolean
          phone_number_id?: string | null
          profile_name?: string | null
          tags?: string[]
          tenant_id?: string
          unread_count?: number
          voided?: boolean
          wa_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "contacts_phone_number_id_fkey"
            columns: ["phone_number_id"]
            isOneToOne: false
            referencedRelation: "phone_numbers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contacts_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      conversations: {
        Row: {
          active_flow_key: string | null
          assigned_to_label: string | null
          contact_id: number
          created_at: string
          flow_state: Json
          flow_status: string
          id: string
          last_agent_msg_at: string | null
          last_user_msg_at: string | null
          mute_bot_until: string | null
          phone_number_id: string | null
          session_expires_at: string | null
          status: Database["public"]["Enums"]["conversation_mode"]
          tenant_id: string
          updated_at: string
          voided: boolean
        }
        Insert: {
          active_flow_key?: string | null
          assigned_to_label?: string | null
          contact_id: number
          created_at?: string
          flow_state?: Json
          flow_status?: string
          id?: string
          last_agent_msg_at?: string | null
          last_user_msg_at?: string | null
          mute_bot_until?: string | null
          phone_number_id?: string | null
          session_expires_at?: string | null
          status?: Database["public"]["Enums"]["conversation_mode"]
          tenant_id: string
          updated_at?: string
          voided?: boolean
        }
        Update: {
          active_flow_key?: string | null
          assigned_to_label?: string | null
          contact_id?: number
          created_at?: string
          flow_state?: Json
          flow_status?: string
          id?: string
          last_agent_msg_at?: string | null
          last_user_msg_at?: string | null
          mute_bot_until?: string | null
          phone_number_id?: string | null
          session_expires_at?: string | null
          status?: Database["public"]["Enums"]["conversation_mode"]
          tenant_id?: string
          updated_at?: string
          voided?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "conversations_contact_id_fkey"
            columns: ["contact_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "conversations_phone_number_id_fkey"
            columns: ["phone_number_id"]
            isOneToOne: false
            referencedRelation: "phone_numbers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "conversations_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      handover_events: {
        Row: {
          action: string
          actor: Json
          at: string
          conversation_id: string
          id: number
        }
        Insert: {
          action: string
          actor: Json
          at?: string
          conversation_id: string
          id?: number
        }
        Update: {
          action?: string
          actor?: Json
          at?: string
          conversation_id?: string
          id?: number
        }
        Relationships: []
      }
      message_template: {
        Row: {
          body: string | null
          category: string
          components: Json
          created_at: string
          id: string
          language: string
          name: string
          previous_category: string | null
          status: string | null
          tenant_id: string | null
          updated_at: string
          voided: boolean
        }
        Insert: {
          body?: string | null
          category: string
          components: Json
          created_at?: string
          id: string
          language: string
          name: string
          previous_category?: string | null
          status?: string | null
          tenant_id?: string | null
          updated_at?: string
          voided?: boolean
        }
        Update: {
          body?: string | null
          category?: string
          components?: Json
          created_at?: string
          id?: string
          language?: string
          name?: string
          previous_category?: string | null
          status?: string | null
          tenant_id?: string | null
          updated_at?: string
          voided?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "message_template_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      messages: {
        Row: {
          chat_id: number
          created_at: string
          delivered_at: string | null
          failed_at: string | null
          id: number
          is_received: boolean
          media_url: string | null
          message: Json
          read_at: string | null
          read_by_user_at: string | null
          sent_at: string | null
          wam_id: string
        }
        Insert: {
          chat_id: number
          created_at?: string
          delivered_at?: string | null
          failed_at?: string | null
          id?: number
          is_received?: boolean
          media_url?: string | null
          message: Json
          read_at?: string | null
          read_by_user_at?: string | null
          sent_at?: string | null
          wam_id: string
        }
        Update: {
          chat_id?: number
          created_at?: string
          delivered_at?: string | null
          failed_at?: string | null
          id?: number
          is_received?: boolean
          media_url?: string | null
          message?: Json
          read_at?: string | null
          read_by_user_at?: string | null
          sent_at?: string | null
          wam_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "messages_chat_fk"
            columns: ["chat_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
        ]
      }
      phone_numbers: {
        Row: {
          auto_handover_on_echo: boolean
          created_at: string
          echo_handover_mute_seconds: number | null
          id: string
          is_active: boolean
          tenant_id: string
          voided: boolean
          wa_phone_number_id: string
          waba_id: string | null
          working_hours_override: Json | null
        }
        Insert: {
          auto_handover_on_echo?: boolean
          created_at?: string
          echo_handover_mute_seconds?: number | null
          id?: string
          is_active?: boolean
          tenant_id: string
          voided?: boolean
          wa_phone_number_id: string
          waba_id?: string | null
          working_hours_override?: Json | null
        }
        Update: {
          auto_handover_on_echo?: boolean
          created_at?: string
          echo_handover_mute_seconds?: number | null
          id?: string
          is_active?: boolean
          tenant_id?: string
          voided?: boolean
          wa_phone_number_id?: string
          waba_id?: string | null
          working_hours_override?: Json | null
        }
        Relationships: [
          {
            foreignKeyName: "phone_numbers_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          email: string | null
          first_name: string | null
          id: string
          last_name: string | null
          last_updated: string | null
        }
        Insert: {
          email?: string | null
          first_name?: string | null
          id: string
          last_name?: string | null
          last_updated?: string | null
        }
        Update: {
          email?: string | null
          first_name?: string | null
          id?: string
          last_name?: string | null
          last_updated?: string | null
        }
        Relationships: []
      }
      role_permissions: {
        Row: {
          id: number
          permission: Database["public"]["Enums"]["app_permission"]
          role: Database["public"]["Enums"]["app_role"]
        }
        Insert: {
          id?: number
          permission: Database["public"]["Enums"]["app_permission"]
          role: Database["public"]["Enums"]["app_role"]
        }
        Update: {
          id?: number
          permission?: Database["public"]["Enums"]["app_permission"]
          role?: Database["public"]["Enums"]["app_role"]
        }
        Relationships: []
      }
      setup: {
        Row: {
          created_at: string | null
          display_text: string
          done_at: string | null
          id: string
          in_progress: boolean
          name: string | null
          sequence: number | null
        }
        Insert: {
          created_at?: string | null
          display_text: string
          done_at?: string | null
          id?: string
          in_progress?: boolean
          name?: string | null
          sequence?: number | null
        }
        Update: {
          created_at?: string | null
          display_text?: string
          done_at?: string | null
          id?: string
          in_progress?: boolean
          name?: string | null
          sequence?: number | null
        }
        Relationships: []
      }
      tenants: {
        Row: {
          address_line1: string | null
          address_line2: string | null
          city: string | null
          config: Json
          country: string | null
          created_at: string
          echo_handover_mute_seconds: number
          email: string | null
          emergency_contacts: Json
          id: string
          languages: string[]
          name: string
          phone_alt: string | null
          phone_main: string | null
          postal_code: string | null
          region: string | null
          retention_days: number | null
          summary: string | null
          timezone: string
          voided: boolean
          website: string | null
          working_hours: Json
        }
        Insert: {
          address_line1?: string | null
          address_line2?: string | null
          city?: string | null
          config?: Json
          country?: string | null
          created_at?: string
          echo_handover_mute_seconds?: number
          email?: string | null
          emergency_contacts?: Json
          id?: string
          languages?: string[]
          name: string
          phone_alt?: string | null
          phone_main?: string | null
          postal_code?: string | null
          region?: string | null
          retention_days?: number | null
          summary?: string | null
          timezone?: string
          voided?: boolean
          website?: string | null
          working_hours?: Json
        }
        Update: {
          address_line1?: string | null
          address_line2?: string | null
          city?: string | null
          config?: Json
          country?: string | null
          created_at?: string
          echo_handover_mute_seconds?: number
          email?: string | null
          emergency_contacts?: Json
          id?: string
          languages?: string[]
          name?: string
          phone_alt?: string | null
          phone_main?: string | null
          postal_code?: string | null
          region?: string | null
          retention_days?: number | null
          summary?: string | null
          timezone?: string
          voided?: boolean
          website?: string | null
          working_hours?: Json
        }
        Relationships: []
      }
      user_roles: {
        Row: {
          id: number
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Insert: {
          id?: number
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Update: {
          id?: number
          role?: Database["public"]["Enums"]["app_role"]
          user_id?: string
        }
        Relationships: []
      }
      webhook: {
        Row: {
          created_at: string | null
          id: number
          payload: Json | null
        }
        Insert: {
          created_at?: string | null
          id?: number
          payload?: Json | null
        }
        Update: {
          created_at?: string | null
          id?: number
          payload?: Json | null
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      add_delivered_count_to_broadcast: {
        Args: { b_id: string; delivered_count_to_be_added: number }
        Returns: undefined
      }
      add_failed_count_to_broadcast: {
        Args: { b_id: string; failed_count_to_be_added: number }
        Returns: undefined
      }
      add_processed_count_to_broadcast: {
        Args: { b_id: string; processed_count_to_be_added: number }
        Returns: undefined
      }
      add_read_count_to_broadcast: {
        Args: { b_id: string; read_count_to_be_added: number }
        Returns: undefined
      }
      add_replied_to_broadcast_contact: {
        Args: { b_id: string; replied_count_to_be_added: number }
        Returns: undefined
      }
      add_sent_count_to_broadcast: {
        Args: { b_id: string; sent_count_to_be_added: number }
        Returns: undefined
      }
      authorize: {
        Args: {
          requested_permission: Database["public"]["Enums"]["app_permission"]
        }
        Returns: boolean
      }
      custom_access_token_hook: { Args: { event: Json }; Returns: Json }
      get_msg_text: { Args: { msg: Json }; Returns: string }
      pick_next_broadcast_batch: { Args: { b_id: string }; Returns: string }
      show_limit: { Args: never; Returns: number }
      show_trgm: { Args: { "": string }; Returns: string[] }
      update_message_delivered_status: {
        Args: { delivered_at_in: string; wam_id_in: string }
        Returns: boolean
      }
      update_message_failed_status: {
        Args: { failed_at_in: string; wam_id_in: string }
        Returns: boolean
      }
      update_message_read_status: {
        Args: { read_at_in: string; wam_id_in: string }
        Returns: boolean
      }
      update_message_sent_status: {
        Args: { sent_at_in: string; wam_id_in: string }
        Returns: boolean
      }
      uuid_generate_v1: { Args: never; Returns: string }
      uuid_generate_v1mc: { Args: never; Returns: string }
      uuid_generate_v3: {
        Args: { name: string; namespace: string }
        Returns: string
      }
      uuid_generate_v4: { Args: never; Returns: string }
      uuid_generate_v5: {
        Args: { name: string; namespace: string }
        Returns: string
      }
      uuid_nil: { Args: never; Returns: string }
      uuid_ns_dns: { Args: never; Returns: string }
      uuid_ns_oid: { Args: never; Returns: string }
      uuid_ns_url: { Args: never; Returns: string }
      uuid_ns_x500: { Args: never; Returns: string }
    }
    Enums: {
      app_permission:
        | "contact.read"
        | "contact.write"
        | "chat.read"
        | "chat.write"
      app_role: "admin" | "agent"
      conversation_mode: "bot" | "handover_pending" | "human" | "closed"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      app_permission: [
        "contact.read",
        "contact.write",
        "chat.read",
        "chat.write",
      ],
      app_role: ["admin", "agent"],
      conversation_mode: ["bot", "handover_pending", "human", "closed"],
    },
  },
} as const
