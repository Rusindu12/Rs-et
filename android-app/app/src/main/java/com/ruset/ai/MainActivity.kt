package com.ruset.ai

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognizerIntent
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage

private val BgDark = Color(0xFF0F172A)
private val BgPurple = Color(0xFF1E1B4B)
private val BubbleBot = Color(0xFF1E293B)
private val Purple = Color(0xFF7C3AED)
private val Indigo = Color(0xFF4F46E5)
private val Lavender = Color(0xFFA78BFA)
private val TextMain = Color(0xFFE2E8F0)
private val TextDim = Color(0xFF94A3B8)
private val Online = Color(0xFF4ADE80)

private val DarkScheme = darkColorScheme(
    primary = Lavender,
    background = BgDark,
    surface = BubbleBot,
    onBackground = TextMain,
    onSurface = TextMain,
)

private val ScreenBrush = Brush.linearGradient(listOf(BgDark, BgPurple))
private val UserBrush = Brush.horizontalGradient(listOf(Purple, Indigo))

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme(colorScheme = DarkScheme) {
                ChatScreen()
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatScreen(vm: ChatViewModel = viewModel()) {
    var showSettings by remember { mutableStateOf(false) }
    val listState = rememberLazyListState()

    LaunchedEffect(vm.messages.size, vm.isTyping) {
        val count = listState.layoutInfo.totalItemsCount
        if (count > 0) listState.animateScrollToItem(count - 1)
    }

    Box(Modifier.fillMaxSize().background(ScreenBrush)) {
        Scaffold(
            containerColor = Color.Transparent,
            topBar = {
                TopAppBar(
                    title = {
                        Column {
                            Text("RS AI", fontWeight = FontWeight.Bold, fontSize = 20.sp)
                            Text(
                                "● සබැඳි · Sinhala + English AI",
                                fontSize = 11.sp,
                                color = Online
                            )
                        }
                    },
                    actions = {
                        IconButton(onClick = { vm.toggleSpeak() }) {
                            Text(if (vm.speakOn) "🔊" else "🔇", fontSize = 20.sp)
                        }
                        IconButton(onClick = { vm.clearChat() }) {
                            Text("🗑️", fontSize = 20.sp)
                        }
                        IconButton(onClick = { showSettings = true }) {
                            Icon(Icons.Default.Settings, "Settings", tint = Lavender)
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(containerColor = BgDark.copy(alpha = 0.85f))
                )
            },
            bottomBar = { InputBar(vm) }
        ) { padding ->
            Column(Modifier.fillMaxSize().padding(padding)) {
                LazyColumn(
                    state = listState,
                    modifier = Modifier.weight(1f).fillMaxWidth(),
                    contentPadding = PaddingValues(vertical = 10.dp)
                ) {
                    items(vm.messages) { msg -> MessageBubble(msg) }
                    if (vm.isTyping) {
                        item { TypingBubble(vm.selectedMode) }
                    }
                }
                ModeRow(vm)
                AttachmentRow(vm)
            }
        }
    }

    if (showSettings) {
        SettingsDialog(vm) { showSettings = false }
    }
}

@Composable
@OptIn(ExperimentalMaterial3Api::class)
fun ModeRow(vm: ChatViewModel) {
    LazyRow(
        modifier = Modifier.fillMaxWidth(),
        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(7.dp)
    ) {
        items(vm.modes) { (key, label) ->
            FilterChip(
                selected = vm.selectedMode == key,
                onClick = { vm.selectMode(key) },
                label = { Text(label, fontSize = 12.sp) },
                colors = FilterChipDefaults.filterChipColors(
                    containerColor = BubbleBot,
                    labelColor = TextDim,
                    selectedContainerColor = Purple,
                    selectedLabelColor = Color.White
                )
            )
        }
    }
}

@Composable
fun AttachmentRow(vm: ChatViewModel) {
    if (vm.attachments.isEmpty()) return
    LazyRow(
        modifier = Modifier.fillMaxWidth(),
        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(7.dp)
    ) {
        items(vm.attachments.toList()) { a ->
            Surface(color = Indigo, shape = RoundedCornerShape(8.dp)) {
                Row(
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        (if (a.kind == "image") "🖼️ " else "📄 ") + a.name.take(20),
                        color = Color.White, fontSize = 12.sp
                    )
                    Text(
                        " ✕",
                        color = Color(0xFFF87171),
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier
                            .padding(start = 6.dp)
                            .clickable { vm.removeAttachment(vm.attachments.indexOf(a)) }
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun MessageBubble(msg: ChatMessage) {
    val uriHandler = LocalUriHandler.current
    val clipboard = LocalClipboardManager.current
    val ctx = LocalContext.current
    Box(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 4.dp),
        contentAlignment = if (msg.isUser) Alignment.CenterEnd else Alignment.CenterStart
    ) {
        if (msg.isUser) {
            Box(
                Modifier
                    .widthIn(max = 300.dp)
                    .background(UserBrush, RoundedCornerShape(20.dp, 20.dp, 6.dp, 20.dp))
                    .padding(horizontal = 14.dp, vertical = 11.dp)
            ) {
                Text(msg.text, color = Color.White, fontSize = 15.sp, lineHeight = 22.sp)
            }
        } else {
            Surface(
                color = BubbleBot,
                shape = RoundedCornerShape(20.dp, 20.dp, 20.dp, 6.dp),
                modifier = Modifier.combinedClickable(
                    onClick = {},
                    onLongClick = {
                        clipboard.setText(AnnotatedString(msg.text))
                        Toast.makeText(ctx, "📋 copied!", Toast.LENGTH_SHORT).show()
                    }
                )
            ) {
                Column(Modifier.widthIn(max = 300.dp).padding(horizontal = 14.dp, vertical = 11.dp)) {
                    if (msg.text.isNotBlank()) {
                        Text(msg.text, color = TextMain, fontSize = 15.sp, lineHeight = 22.sp)
                    }
                    msg.imageUrl?.let { url ->
                        AsyncImage(
                            model = url,
                            contentDescription = "generated image",
                            modifier = Modifier
                                .fillMaxWidth()
                                .heightIn(max = 280.dp)
                                .padding(top = if (msg.text.isBlank()) 0.dp else 8.dp)
                                .clip(RoundedCornerShape(12.dp)),
                            contentScale = ContentScale.Crop
                        )
                    }
                    if (!msg.sources.isNullOrEmpty()) {
                        Text("📚 මූලාශ්‍ර", color = TextDim, fontSize = 11.sp,
                            fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 8.dp))
                        msg.sources.forEach { s ->
                            Text(
                                "• ${s.title}",
                                color = Lavender,
                                fontSize = 11.sp,
                                lineHeight = 16.sp,
                                modifier = Modifier
                                    .padding(top = 2.dp)
                                    .clickable {
                                        if (s.url.isNotBlank()) uriHandler.openUri(s.url)
                                    }
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun TypingBubble(mode: String) {
    val transition = rememberInfiniteTransition(label = "typing")
    val alpha by transition.animateFloat(
        initialValue = 0.35f, targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(700), RepeatMode.Reverse),
        label = "alpha"
    )
    val label = when (mode) {
        "think" -> "💡 RS AI හිතමින්…"
        "think_harder" -> "🧠 ගැඹුරුව හිතමින්…"
        "research" -> "🔬 research කරමින්…"
        "image" -> "🎨 image හදමින්…"
        else -> "RS AI ටයිප් කරමින්…"
    }
    Box(
        Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 4.dp),
        contentAlignment = Alignment.CenterStart
    ) {
        Surface(color = BubbleBot, shape = RoundedCornerShape(20.dp, 20.dp, 20.dp, 6.dp)) {
            Text(
                label,
                modifier = Modifier.padding(horizontal = 14.dp, vertical = 11.dp),
                color = TextDim.copy(alpha = alpha),
                fontSize = 13.sp
            )
        }
    }
}

@Composable
fun InputBar(vm: ChatViewModel) {
    val ctx = LocalContext.current
    var text by remember { mutableStateOf("") }

    // --- launchers ---
    val micLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { res ->
        val said = res.data
            ?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
            ?.firstOrNull()
        if (!said.isNullOrBlank()) text = said
    }

    fun launchMic(launch: (Intent) -> Unit = micLauncher::launch) {
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "si-LK")
            putExtra(RecognizerIntent.EXTRA_PROMPT, "කතා කරන්න… 🎙️")
        }
        try {
            launch(intent)
        } catch (e: Exception) {
            // no recognizer service on this device
        }
    }

    val micPermLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) launchMic()
    }

    val camLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.TakePicturePreview()
    ) { bmp -> bmp?.let(vm::addBitmapAttachment) }

    val imgLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri -> uri?.let(vm::addUriAttachment) }

    val fileLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri -> uri?.let(vm::addUriAttachment) }

    Surface(color = BgDark.copy(alpha = 0.92f)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .imePadding()
                .padding(horizontal = 8.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            AttachButton("📁") { fileLauncher.launch("*/*") }
            AttachButton("🖼️") { imgLauncher.launch("image/*") }
            AttachButton("📷") { camLauncher.launch(null) }
            AttachButton("🎙️") {
                val granted = ContextCompat.checkSelfPermission(
                    ctx, Manifest.permission.RECORD_AUDIO
                ) == PackageManager.PERMISSION_GRANTED
                if (granted) launchMic() else micPermLauncher.launch(Manifest.permission.RECORD_AUDIO)
            }

            OutlinedTextField(
                value = text,
                onValueChange = { text = it },
                modifier = Modifier.weight(1f).padding(horizontal = 6.dp),
                placeholder = {
                    Text(
                        when (vm.selectedMode) {
                            "image" -> "ඇඳන්න ඕන දේ… 🎨"
                            "research" -> "research මාතෘකාව… 🔬"
                            else -> "මෙසේජ් එකක්…"
                        },
                        color = TextDim, fontSize = 14.sp
                    )
                },
                shape = RoundedCornerShape(50),
                maxLines = 4,
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = Purple,
                    unfocusedBorderColor = TextDim.copy(alpha = 0.4f),
                    focusedContainerColor = BubbleBot,
                    unfocusedContainerColor = BubbleBot,
                    focusedTextColor = TextMain,
                    unfocusedTextColor = TextMain
                )
            )
            Box(
                modifier = Modifier
                    .size(46.dp)
                    .background(UserBrush, CircleShape),
                contentAlignment = Alignment.Center
            ) {
                IconButton(
                    onClick = {
                        if (vm.isTyping) vm.stopGeneration() else { vm.send(text); text = "" }
                    },
                    enabled = (text.isNotBlank() || vm.attachments.isNotEmpty() || vm.isTyping)
                ) {
                    Text(if (vm.isTyping) "⏹" else "➤", color = Color.White, fontSize = 17.sp)
                }
            }
        }
    }
}

@Composable
fun AttachButton(emoji: String, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .size(38.dp)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Text(emoji, fontSize = 18.sp)
    }
}

@Composable
fun SettingsDialog(vm: ChatViewModel, onDismiss: () -> Unit) {
    var url by remember { mutableStateOf(vm.serverUrl) }
    var token by remember { mutableStateOf(vm.apiToken) }
    var testResult by remember { mutableStateOf<String?>(null) }
    val uriHandler2 = LocalUriHandler.current

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = BubbleBot,
        title = { Text("⚙️ Server Settings", color = TextMain) },
        text = {
            Column {
                Text(
                    "RS AI server ලිපිනය:\n" +
                        "• Emulator නම්: http://10.0.2.2:8000\n" +
                        "• Phone (Wi-Fi): http://<PC IP>:8000\n" +
                        "• Public (Colab/tunnel): https://xxx.trycloudflare.com\n" +
                        "💡 සැබෑ phone එකක 10.0.2.2 වැඩ කරන්නේ නෑ — public URL එකක් ඕන!",
                    fontSize = 13.sp, color = TextDim, lineHeight = 19.sp
                )
                Text(
                    "🚀 Easiest: Colab (free, minutes!)",
                    color = Lavender, fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(top = 8.dp).clickable {
                        uriHandler2.openUri("https://colab.research.google.com/github/Rusindu12/Rs-et/blob/main/notebooks/RS_AI_Colab.ipynb")
                    }
                )
                OutlinedTextField(
                    value = url,
                    onValueChange = { url = it },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
                    placeholder = { Text("https://your-server") },
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = Purple,
                        focusedTextColor = TextMain,
                        unfocusedTextColor = TextMain
                    )
                )
                Row(Modifier.padding(top = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                    TextButton(onClick = {
                        vm.updateServerUrl(url)
                        vm.updateApiToken(token)
                        testResult = null
                        vm.testConnection { ok, detail -> testResult = detail }
                    }) {
                        Text("🔗 Test connection", color = Lavender, fontWeight = FontWeight.Bold)
                    }
                    if (vm.healthCheckRunning.value) {
                        Text("⏳", fontSize = 16.sp, modifier = Modifier.padding(start = 6.dp))
                    }
                }
                testResult?.let {
                    Text(
                        it,
                        color = if (it.startsWith("✅")) Online else Color(0xFFF87171),
                        fontSize = 12.sp, lineHeight = 16.sp,
                        modifier = Modifier.padding(top = 4.dp)
                    )
                }
                OutlinedTextField(
                    value = token,
                    onValueChange = { token = it },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth().padding(top = 10.dp),
                    placeholder = { Text("API token (optional)", color = TextDim) },
                    label = { Text("API token", color = TextDim) },
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = Purple,
                        focusedTextColor = TextMain,
                        unfocusedTextColor = TextMain
                    )
                )
            }
        },
        confirmButton = {
            TextButton(onClick = {
                vm.updateServerUrl(url)
                vm.updateApiToken(token)
                onDismiss()
            }) {
                Text("Save", color = Lavender, fontWeight = FontWeight.Bold)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel", color = TextDim) }
        }
    )
}
