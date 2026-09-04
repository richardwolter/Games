# Recovers a true alpha channel from the same image rendered twice: once on a
# white background, once on black. Exact, not a heuristic.
#
#   Cw = C*a + 255*(1-a)      (render over white)
#   Cb = C*a                  (render over black)
#   =>  a = 1 - (Cw - Cb)/255       and      C = Cb / a
#
# This is how you get clean edges out of an image model that cannot emit alpha
# (Gemini / Nano Banana, Imagen, FLUX). It reconstructs antialiased edges and
# genuine semi-transparency, which no background-removal heuristic can do.
#
# Usage:
#   .\alpha_from_pair.ps1 -White on_white.png -Black on_black.png -Out sprite.png
#
# The two renders must be pixel-aligned: same prompt, same seed, only the
# background instruction differs. If the model drifts between the two renders
# this produces garbage - check the reported drift number.

param(
    [Parameter(Mandatory = $true)][string]$White,
    [Parameter(Mandatory = $true)][string]$Black,
    [Parameter(Mandatory = $true)][string]$Out,
    # Alpha below this is snapped to 0, above 255-this is snapped to 255. Kills
    # the low-level mush the model leaves in nominally empty areas.
    [int]$Deadzone = 6
)

Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class AlphaPair
{
    static byte[] Read(string path, out int w, out int h, out int stride)
    {
        Bitmap b = new Bitmap(path);
        w = b.Width; h = b.Height;
        BitmapData bd = b.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        stride = bd.Stride;
        byte[] buf = new byte[stride * h];
        Marshal.Copy(bd.Scan0, buf, 0, buf.Length);
        b.UnlockBits(bd);
        b.Dispose();
        return buf;
    }

    public static string Run(string whitePath, string blackPath, string outPath, int deadzone)
    {
        int ww, wh, wstride, bw, bh, bstride;
        byte[] W = Read(whitePath, out ww, out wh, out wstride);
        byte[] B = Read(blackPath, out bw, out bh, out bstride);

        if (ww != bw || wh != bh)
            return "ERROR: size mismatch - white is " + ww + "x" + wh + ", black is " + bw + "x" + bh;

        Bitmap dst = new Bitmap(ww, wh, PixelFormat.Format32bppArgb);
        BitmapData db = dst.LockBits(new Rectangle(0, 0, ww, wh), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
        byte[] O = new byte[db.Stride * wh];

        double drift = 0.0;
        long opaque = 0, partial = 0, clear = 0;

        for (int y = 0; y < wh; y++)
            for (int x = 0; x < ww; x++)
            {
                int wo = y * wstride + x * 4, bo = y * bstride + x * 4, oo = y * db.Stride + x * 4;

                // alpha per channel, then averaged - channel noise cancels out
                double aSum = 0;
                for (int c = 0; c < 3; c++)
                {
                    double diff = (double)W[wo + c] - (double)B[bo + c];
                    if (diff < 0) { drift += -diff; diff = 0; }      // white render darker than black: model drifted
                    if (diff > 255) { drift += diff - 255; diff = 255; }
                    aSum += 1.0 - diff / 255.0;
                }
                double a = aSum / 3.0;
                if (a < 0) a = 0; if (a > 1) a = 1;

                double af = a * 255.0;
                if (af <= deadzone) { af = 0; a = 0; }
                else if (af >= 255 - deadzone) { af = 255; a = 1; }

                if (a <= 0) { clear++; O[oo] = 0; O[oo + 1] = 0; O[oo + 2] = 0; O[oo + 3] = 0; continue; }
                if (a >= 1) opaque++; else partial++;

                // un-premultiply: the black render is already C*a
                for (int c = 0; c < 3; c++)
                {
                    double v = B[bo + c] / a;
                    if (v < 0) v = 0; if (v > 255) v = 255;
                    O[oo + c] = (byte)Math.Round(v);
                }
                O[oo + 3] = (byte)Math.Round(af);
            }

        Marshal.Copy(O, 0, db.Scan0, O.Length);
        dst.UnlockBits(db);
        dst.Save(outPath, ImageFormat.Png);
        dst.Dispose();

        double driftPerPx = drift / (ww * wh * 3.0);
        return string.Format("{0}x{1}  opaque={2} edge={3} clear={4}  drift={5:F2}/px{6}",
            ww, wh, opaque, partial, clear, driftPerPx,
            driftPerPx > 4.0 ? "  <-- HIGH, the two renders disagree; regenerate with a fixed seed" : "");
    }
}
"@ -ReferencedAssemblies System.Drawing

$Out = [System.IO.Path]::GetFullPath($Out)
$msg = [AlphaPair]::Run(
    [System.IO.Path]::GetFullPath($White),
    [System.IO.Path]::GetFullPath($Black),
    $Out, $Deadzone)
Write-Host $msg
