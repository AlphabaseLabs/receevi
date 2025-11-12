create table "public"."appointment_reminders" (
    "id" uuid not null default gen_random_uuid(),
    "wa_id" numeric not null,
    "send_by" character varying(20) not null,
    "cancel_by" character varying(20),
    "status" character varying(50) not null,
    "template_id" character varying not null,
    "patient_response" text,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now(),
    "appointment_uuid" uuid
);


alter table "public"."contacts" disable row level security;

alter table "public"."message_template" disable row level security;

alter table "public"."messages" disable row level security;

CREATE UNIQUE INDEX appointment_reminders_pkey ON public.appointment_reminders USING btree (id);

CREATE INDEX idx_appointment_reminders_cancel_by ON public.appointment_reminders USING btree (cancel_by);

CREATE INDEX idx_appointment_reminders_created_at ON public.appointment_reminders USING btree (created_at);

CREATE INDEX idx_appointment_reminders_send_by ON public.appointment_reminders USING btree (send_by);

CREATE INDEX idx_appointment_reminders_status ON public.appointment_reminders USING btree (status);

CREATE INDEX idx_appointment_reminders_wa_id ON public.appointment_reminders USING btree (wa_id);

alter table "public"."appointment_reminders" add constraint "appointment_reminders_pkey" PRIMARY KEY using index "appointment_reminders_pkey";

alter table "public"."appointment_reminders" add constraint "appointment_reminders_wa_id_fkey" FOREIGN KEY (wa_id) REFERENCES contacts(wa_id) ON DELETE CASCADE not valid;

alter table "public"."appointment_reminders" validate constraint "appointment_reminders_wa_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  NEW.updated_at := now();  -- use timezone('utc', now()) if you want UTC
  return NEW;
end;
$function$
;

grant delete on table "public"."appointment_reminders" to "anon";

grant insert on table "public"."appointment_reminders" to "anon";

grant references on table "public"."appointment_reminders" to "anon";

grant select on table "public"."appointment_reminders" to "anon";

grant trigger on table "public"."appointment_reminders" to "anon";

grant truncate on table "public"."appointment_reminders" to "anon";

grant update on table "public"."appointment_reminders" to "anon";

grant delete on table "public"."appointment_reminders" to "authenticated";

grant insert on table "public"."appointment_reminders" to "authenticated";

grant references on table "public"."appointment_reminders" to "authenticated";

grant select on table "public"."appointment_reminders" to "authenticated";

grant trigger on table "public"."appointment_reminders" to "authenticated";

grant truncate on table "public"."appointment_reminders" to "authenticated";

grant update on table "public"."appointment_reminders" to "authenticated";

grant delete on table "public"."appointment_reminders" to "service_role";

grant insert on table "public"."appointment_reminders" to "service_role";

grant references on table "public"."appointment_reminders" to "service_role";

grant select on table "public"."appointment_reminders" to "service_role";

grant trigger on table "public"."appointment_reminders" to "service_role";

grant truncate on table "public"."appointment_reminders" to "service_role";

grant update on table "public"."appointment_reminders" to "service_role";

CREATE TRIGGER appointment_reminders_update_updated_at BEFORE UPDATE ON public.appointment_reminders FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();


