package com.ruset.ai

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SuggestionChip
import androidx.compose.material3.SuggestionChipDefaults
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel

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
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(vertical = 12.dp)
                ) {
                    items(vm.messages) { msg -> MessageBubble(msg) }
                    if (vm.isTyping) {
                        item { TypingBubble() }
                    }
                }

                if (vm.messages.size <= 1) {
                    SuggestionRow(vm)
                }
            }
        }
    }

    if (showSettings) {
        SettingsDialog(vm) { showSettings = false }
    }
}

@Composable
fun MessageBubble(msg: ChatMessage) {
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
                shape = RoundedCornerShape(20.dp, 20.dp, 20.dp, 6.dp)
            ) {
                Text(
                    msg.text,
                    modifier = Modifier.widthIn(max = 300.dp).padding(horizontal = 14.dp, vertical = 11.dp),
                    color = TextMain,
                    fontSize = 15.sp,
                    lineHeight = 22.sp
                )
            }
        }
    }
}

@Composable
fun TypingBubble() {
    val transition = rememberInfiniteTransition(label = "typing")
    val alpha by transition.animateFloat(
        initialValue = 0.35f, targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(700), RepeatMode.Reverse),
        label = "alpha"
    )
    Box(
        Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 4.dp),
        contentAlignment = Alignment.CenterStart
    ) {
        Surface(color = BubbleBot, shape = RoundedCornerShape(20.dp, 20.dp, 20.dp, 6.dp)) {
            Text(
                "RS AI ටයිප් කරමින්…",
                modifier = Modifier.padding(horizontal = 14.dp, vertical = 11.dp),
                color = TextDim.copy(alpha = alpha),
                fontSize = 13.sp
            )
        }
    }
}

@Composable
fun SuggestionRow(vm: ChatViewModel) {
    val suggestions = listOf(
        "ඔයා කවුද?",
        "සීගිරිය ගැන කියන්න",
        "AI කියන්නේ මොකක්ද?",
        "What can you do?"
    )
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = 12.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        suggestions.forEach { q ->
            SuggestionChip(
                onClick = { vm.send(q) },
                label = { Text(q, fontSize = 13.sp) },
                colors = SuggestionChipDefaults.suggestionChipColors(
                    containerColor = BubbleBot,
                    labelColor = Lavender
                )
            )
        }
    }
}

@Composable
fun InputBar(vm: ChatViewModel) {
    var text by remember { mutableStateOf("") }

    fun doSend() {
        vm.send(text)
        text = ""
    }

    Surface(color = BgDark.copy(alpha = 0.92f)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .imePadding()
                .padding(horizontal = 12.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            OutlinedTextField(
                value = text,
                onValueChange = { text = it },
                modifier = Modifier.weight(1f),
                placeholder = { Text("මෙසේජ් එකක් ලියන්න…", color = TextDim) },
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
                    .padding(start = 10.dp)
                    .size(48.dp)
                    .background(UserBrush, CircleShape),
                contentAlignment = Alignment.Center
            ) {
                IconButton(onClick = { doSend() }, enabled = text.isNotBlank() && !vm.isTyping) {
                    Icon(Icons.Default.Send, "Send", tint = Color.White)
                }
            }
        }
    }
}

@Composable
fun SettingsDialog(vm: ChatViewModel, onDismiss: () -> Unit) {
    var url by remember { mutableStateOf(vm.serverUrl) }
    var token by remember { mutableStateOf(vm.apiToken) }

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = BubbleBot,
        title = { Text("⚙️ Server Settings", color = TextMain) },
        text = {
            Column {
                Text(
                    "RS AI server එක ලියුම් ලිපිනය.\n" +
                        "• Emulator: http://10.0.2.2:8000\n" +
                        "• Phone (එකම Wi-Fi): http://<PC IP>:8000\n" +
                        "• Public server නම් deploy URL එක + token",
                    fontSize = 13.sp, color = TextDim, lineHeight = 19.sp
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
                vm.setServerUrl(url)
                vm.setApiToken(token)
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
