DROP POLICY IF EXISTS "Give download permission to authenticated user 1ps738_0" ON "storage"."objects";

CREATE POLICY "Give download permission to authenticated user 1ps738_0"
ON "storage"."objects"
AS permissive
FOR SELECT
TO authenticated
USING ((bucket_id = 'media'::text));



