// Supabase Edge Function: permanently deletes the calling user's account
// (spec 5.14, 10.3). Runs with the service role because by the time
// storage cleanup happens the user's own session is being torn down -
// the anon-key client can never do this itself (delete_account_data() in
// supabase/migrations/20260817000010_rpc_functions.sql explicitly
// revokes execute from `authenticated`).
//
// Deploy: supabase functions deploy delete-account
// Call from the app via SupabaseBackend.deleteAccount(), which invokes
// this with the user's own access token in the Authorization header so
// we can verify identity before using elevated privileges.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), { status: 401 });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // Verify the caller's own identity using their token against the
    // anon-scoped client first - never trust a user id passed in the
    // request body.
    const callerClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userError } = await callerClient.auth.getUser();
    if (userError || !userData?.user) {
      return new Response(JSON.stringify({ error: "Could not verify caller identity" }), { status: 401 });
    }
    const userId = userData.user.id;

    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    // delete_account_data() cascades every workspace/purchase/item/
    // attachment row and returns the storage paths that need cleanup
    // (Postgres can't reach into Storage itself).
    const { data: storagePaths, error: rpcError } = await adminClient.rpc("delete_account_data", { p_user_id: userId });
    if (rpcError) {
      return new Response(JSON.stringify({ error: rpcError.message }), { status: 500 });
    }

    const paths = (storagePaths ?? []).map((row: { storage_path: string }) => row.storage_path);
    if (paths.length > 0) {
      const { error: storageError } = await adminClient.storage.from("proof-files").remove(paths);
      if (storageError) {
        // Data rows are already gone; log and continue rather than
        // leaving the account undeletable over an orphaned file.
        console.error("Storage cleanup partial failure:", storageError.message);
      }
    }

    const { error: deleteUserError } = await adminClient.auth.admin.deleteUser(userId);
    if (deleteUserError) {
      return new Response(JSON.stringify({ error: deleteUserError.message }), { status: 500 });
    }

    return new Response(JSON.stringify({ success: true }), { status: 200, headers: { "Content-Type": "application/json" } });
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), { status: 500 });
  }
});
