# Reuse only the Supabase CLI login. Never print or persist the credential.
# CLI source: apps/cli-go/internal/utils/{access_token.go,credentials/store.go}
function Get-SeedRoverSupabaseToken {
    if ($env:SUPABASE_ACCESS_TOKEN) { return $env:SUPABASE_ACCESS_TOKEN }
    if (-not ('SeedRoverSupabaseCredential' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class SeedRoverSupabaseCredential {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct Credential {
        public uint Flags, Type;
        public string TargetName, Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public uint BlobSize;
        public IntPtr Blob;
        public uint Persist, AttributeCount;
        public IntPtr Attributes;
        public string TargetAlias, UserName;
    }
    [DllImport("advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern bool Read(string target, uint type, uint flags, out IntPtr credential);
    [DllImport("advapi32.dll")] static extern void CredFree(IntPtr credential);
    public static string ReadSupabaseLogin() {
        foreach (string target in new[] { "Supabase CLI:supabase", "Supabase CLI:access-token" }) {
            IntPtr pointer;
            if (!Read(target, 1, 0, out pointer)) continue;
            try {
                var credential = (Credential)Marshal.PtrToStructure(pointer, typeof(Credential));
                var bytes = new byte[credential.BlobSize];
                Marshal.Copy(credential.Blob, bytes, 0, bytes.Length);
                string token = Encoding.UTF8.GetString(bytes);
                Array.Clear(bytes, 0, bytes.Length);
                const string prefix = "go-keyring-base64:";
                return token.StartsWith(prefix) ? Encoding.UTF8.GetString(Convert.FromBase64String(token.Substring(prefix.Length))) : token;
            } finally { CredFree(pointer); }
        }
        throw new InvalidOperationException("Supabase CLI login unavailable. Run supabase login first.");
    }
}
'@
    }
    return [SeedRoverSupabaseCredential]::ReadSupabaseLogin()
}

function Invoke-SeedRoverSupabaseRead {
    param([Parameter(Mandatory)][string]$Path)
    if ($Path -notmatch '^/(v1|platform)/' -or $Path -match '[\r\n]') {
        throw 'Only Supabase management read paths are allowed.'
    }
    $token = Get-SeedRoverSupabaseToken
    try {
        Invoke-RestMethod -Method Get -Uri ('https://api.supabase.com' + $Path) `
            -Headers @{ Authorization = "Bearer $token" } -TimeoutSec 30 -MaximumRedirection 0
    } finally { $token = $null }
}
