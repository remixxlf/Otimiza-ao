$code = @'
$source = @"
using System;
using System.Runtime.InteropServices;
public class SysHelpers {
    [DllImport(""ntdll.dll"")]
    public static extern uint NtSetSystemInformation(int InfoClass, IntPtr Info, int Length);
    public static void Flush() {
        int[] arr = new int[] { 4 };
        GCHandle h = GCHandle.Alloc(arr, GCHandleType.Pinned);
        NtSetSystemInformation(80, h.AddrOfPinnedObject(), 4);
        h.Free();
    }
}
"@
Add-Type -TypeDefinition $source -ErrorAction SilentlyContinue
try { [SysHelpers]::Flush() } catch {}
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
'@
$base64 = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($code))
Write-Host $base64
