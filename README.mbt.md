# sennenki/pretty_prompt

`pretty_prompt` 是一个可配置的终端交互输入库，提供：

- 可定制 prompt 样式
- 历史记录与持久化
- 自动补全与重载提示
- 语法高亮与选区渲染
- 粘贴处理（含多行去缩进）
- 可扩展的按键绑定与回调

## 安装

```bash
moon add sennenki/pretty_prompt
moon add sennenki/pretty_prompt/system
```

在 `moon.pkg` 中导入：

```moonbit nocheck
import {
  "sennenki/pretty_prompt" @pp,
  "sennenki/pretty_prompt/system" @sys,
}
```

## 快速开始

```moonbit nocheck
///|
async fn main {
  let prompt = @pp.Prompt::new(
    @sys.SystemConsolePort::new(),
    @sys.SystemClipboardPort::new(),
  )

  let result = prompt.read_line()
  if result.is_success {
    println("you typed: \{result.text}")
  }

  prompt.dispose()
}
```

`PromptResult` 的主要字段：

- `is_success`：是否成功提交（不是取消）
- `text`：输入文本
- `submit_key_info`：触发提交的按键信息

## 使用自定义 Prompt 文本

```moonbit nocheck
///|
async fn main {
  let prompt = @pp.Prompt::new(
    @sys.SystemConsolePort::new(),
    @sys.SystemClipboardPort::new(),
  )

  let title = @pp.FormattedString::new(">>> ")
  let result = prompt.read_line_with_prompt(title)
  if result.is_success {
    println(result.text)
  }

  prompt.dispose()
}
```

## PromptConfiguration（重点）

通过 `PromptConfiguration::new(...)` 配置行为：

- `prompt`：默认 prompt 文本与样式
- `key_bindings`：按键绑定
- `history`：历史记录策略
- `callbacks`：高亮、补全、格式化等回调
- `selection_background`：选区背景色
- `use_colors`：是否启用颜色
- `max_completion_items_count`：补全窗口最大条数
- `kill_ring_max_size`：kill ring 大小

示例：

```moonbit nocheck
///|
fn make_configuration() -> @pp.PromptConfiguration {
  @pp.PromptConfiguration::new(
    prompt=@pp.FormattedString::new("moon> "),
    history=@pp.HistoryConfiguration::new(
      persistent_history_filepath=".pretty_prompt_history",
      max_entries=1000,
    ),
    use_colors=true,
    max_completion_items_count=8,
  )
}
```

## KeyBindings（重点）

用 `KeyBindings::new(...)` 只覆盖你关心的按键，未指定项保持默认。

当前默认里：

- 提交：`Enter`
- 软换行：`Ctrl+Enter`

示例：把软换行改成 `Shift+Enter`：

```moonbit nocheck
///|
fn make_key_bindings() -> @pp.KeyBindings {
  @pp.KeyBindings::new(
    new_line=@pp.KeyPressPatterns::single(
      @pp.KeyPressPattern::new(@console.Enter, shift=true),
    ),
  )
}
```

## PromptCallbacks（重点）

`PromptCallbacks` 允许你注入编辑体验：

- `highlight_callback`：输入高亮
- `completion_span_provider` / `completion_items_provider`：补全范围与候选
- `should_open_completion_window`：是否弹补全窗
- `confirm_completion_commit`：是否接受本次补全提交
- `transform_key_press`：按键事件变换
- `format_input`：输入后格式化文本与光标
- `should_insert_soft_newline`：提交键是否转成软换行
- `overload_provider`：函数签名提示
- `key_press_callbacks`：特定按键直接触发行为

最小回调示例：

```moonbit nocheck
///|
fn make_callbacks() -> @pp.PromptCallbacks {
  @pp.PromptCallbacks::new(
    completion_items_provider=_ => {
      [@pp.CompletionItem::new("print"), @pp.CompletionItem::new("println")]
    },
    should_open_completion_window=_ => false,
    should_insert_soft_newline=(snapshot, _) => !snapshot.text.trim().is_empty(),
  )
}
```

## 历史记录持久化

```moonbit nocheck
///|
let history = @pp.HistoryConfiguration::new(
  persistent_history_filepath=".pretty_prompt_history",
  max_entries=500,
)
```

行为说明：

- 启动时自动加载历史文件
- 提交后写入历史
- `prompt.dispose()` 时执行最终保存

## 自定义 Console / Clipboard

如果你不想用系统默认实现，可以实现这两个 trait：

- `ConsolePort`
- `ClipboardPort`

然后传给 `Prompt::new(console, clipboard, configuration~)`。

这对测试、远程终端桥接或嵌入式场景很有用。

## 常见注意事项

- 终端对 `Shift+Enter` / `Ctrl+Enter` 的区分能力取决于终端协议，不是所有终端都能可靠区分。
- 宽字符（CJK/emoji）渲染依赖显示宽度计算，建议 prompt 文本尽量稳定。
- 粘贴文本会做标准化处理（含 CRLF 兼容与多行去缩进）。
