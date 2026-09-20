/// Supabase project. The anon key is a public, RLS-protected key meant to ship in clients.
/// Override at build time with --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://qvdaelwujcerllbqufvn.supabase.co',
);
const supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2ZGFlbHd1amNlcmxsYnF1ZnZuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk4NDA0ODcsImV4cCI6MjEwNTQxNjQ4N30.mrPcmZ0pGbIFOkXH-tHxRBxrStBoyXmoyFEdbLn8Q6M',
);

/// Public origin used in shared links. Empty = the origin the app is served from.
const publicBaseUrl = String.fromEnvironment(
  'PUBLIC_BASE_URL',
  defaultValue: '',
);
