// Uzupelnij ponizsze dwie wartosci danymi ze swojego projektu Supabase:
// Dashboard -> Project Settings -> API -> Project URL / anon public key.
// anon key jest bezpieczny do umieszczenia w kodzie frontendowym -
// dostep do danych kontroluja polityki RLS w schema.sql.
export const SUPABASE_URL = 'https://tmlaeinytlxyaavalmle.supabase.co';
export const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRtbGFlaW55dGx4eWFhdmFsbWxlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU2MDA0OTQsImV4cCI6MjEwMTE3NjQ5NH0.UBHyYeq5UEXFcS6QvgG4D-e5aWcHUqdPBQ1EMJBOyG8';

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
