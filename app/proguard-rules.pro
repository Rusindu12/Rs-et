# Keep the JavaScript bridge methods
-keepclassmembers class com.rset.binanceai.MainActivity$NativeBridge {
    @android.webkit.JavascriptInterface <methods>;
}
-keepattributes JavascriptInterface
