# WebBridgeKit Design System

> 面向 iOS 开发者工具的设计系统，统一 WebBridgeKit 三端（iOS / Web / Server）的视觉语言。

## 概述

WebBridgeKit Design System 是一套完整的 UI 设计语言，覆盖色彩、排版、间距、圆角、阴影、图标、动效等视觉基础，以及 52 个核心组件的交互规范。所有 token 通过 CSS 自定义属性（`--wbk-*`）暴露，支持 light/dark 双主题自动切换。

## 视觉基础 (Visual Foundations)

| 分类 | 数量 | 说明 |
|------|------|------|
| 色彩 (Color) | 31 token + 21 兼容别名 | 7 组：background、surface、text、border、brand、semantic、navigation |
| 排版 (Typography) | 15 个文本样式 + 12 个等宽变体 + 15 个独立属性集 | 使用 `font` 简写属性，含字重/字号/行高/字体系列 |
| 间距 (Spacing) | 12 级 | `--wbk-spacing-{xxs,xs,sm,md,lg,xl,xxl,xxxl,section,screen-*}` |
| 圆角 (Radius) | 12 级 | `--wbk-radius-{xs,sm,md,row,lg,card,sheet,xxl,xl,full,avatar,pill}` |
| 阴影 (Shadows) | 7 级 + 6 个旧版别名 | `--wbk-shadow-{none,sm,md,card,fab,lg,sheet}` |
| 图标 (Icons) | 11 个尺寸 | `--wbk-icon-{xs,sm,md,lg,xl,xxl,empty,tab,settings,quick-action,chevron}` |
| 不透明度 (Opacity) | 9 级 | `--wbk-opacity-{disabled,pressed,hover,separator,badge,scrim,overlay,placeholder}` |
| 渐变 (Gradients) | 9 组 | brand、blue、green、orange、pink、purple、sky、peach、cyan，含 start/end/angle |
| 动效 (Animation) | 13 token | `--wbk-animation-{fast,normal,slow,spring,sheet,modal}-{duration,curve,damping}` |
| 断点 (Breakpoints) | 3 级 | compact (320px)、regular (375px)、large (428px) |
| 组件契约 (Contracts) | 39 token | 各组件专有的尺寸/高度/内边距/圆角参数 |

## 命名规范

所有 token 以 `--wbk-*` 为前缀，采用 kebab-case。iOS 端的 `ThemeTokens.Color.*` 枚举与之对应。

**色彩分组规则：**

- `--wbk-background-*` — 页面背景色
- `--wbk-surface-*` / `--wbk-card-background` — 卡片/表面色
- `--wbk-text-*` / `--wbk-placeholder` — 文字颜色
- `--wbk-border` / `--wbk-separator` — 边框与分割线
- `--wbk-primary-*` / `--wbk-accent-*` — 品牌色
- `--wbk-success/warning/error/info/offline` — 语义色
- `--wbk-navigation-bar-*` / `--wbk-tab-bar-*` — 导航色

**兼容别名：** `--color-*` / `--radius-*` / `--space-*` / `--shadow-*` / `--type-*` 层提供跨平台可移植性。

## 深色模式

全部 31 个色彩 token 在 `.dark` 选择器下均有独立的深色覆盖值。切换方式：

```css
/* 自动跟随系统 */
@media (prefers-color-scheme: dark) {
  :root { /* 应用 .dark 中的值 */ }
}

/* 手动切换 */
<html class="dark">
```

深色模式下阴影的 alpha 值相应升高，表面色采用 `#13171D` ~ `#1E2233` 系列深底色。

## 组件清单（components/index.json）

| 组件 | Slug | 类型 | 变体概述 |
|------|------|------|----------|
| 按钮 | `button` | button | Primary / Secondary / Ghost，含 hover/pressed/disabled 状态 |
| 卡片 | `card` | card | ResourceCard / ActionTile / MessageCell，含不同圆角和高度 |
| 设置行 | `settings-row` | row | 标准 54pt ~ 64pt 高度，含图标 + 标题 + 右箭头 |
| 标签栏 | `tab-bar` | navigation | 56pt 高度，23px 图标 + 11px 标签 |
| 搜索框 | `search-field` | input | 44pt 高度，12px 圆角，18px 搜索图标 |
| 筛选标签 | `filter-pill` | badge | 34pt 高度，水平内边距 14px，最小宽度 56px |
| 消息单元 | `message-cell` | message | 收件箱消息行，72-96px 高度，含未读红点、来源标签、标题、正文、时间 |
| 消息详情 | `message-detail` | detail | 完整消息视图，含头部来源标签、标题、正文、元数据行、操作按钮 |
| 弹窗 | `dialog` | modal | 模态弹窗，确认/警告/信息三种样式，遮罩 + 图标 + 标题 + 正文 + 按钮 |
| 状态标签 | `badge` | badge | 资源状态标签，persistent/cached/needsUpdate/notCached 四种颜色 |
| 开关 | `toggle-switch` | input | iOS 风格滑动开关，51x31px 轨道，27px 白圆滑块 |
| 应用卡片 | `app-card` | card | 首页 2 列网格应用卡片，含渐变图标、状态圆点、时间 |
| 统计块 | `stats-tile` | data | 推送统计 2x2 数据磁贴，数字 24px 700 + 标签 11px |
| 空状态 | `empty-state` | placeholder | 居中空状态提示，含图标、标题、正文、可选操作按钮 |
| 表格 | `table` | data | 数据表格，含表头、行分隔线、状态标签列 |
| 导航头 | `nav-header` | navigation | 44px 子页面导航栏，含返回按钮、居中标题、右侧操作 |
| 加载指示 | `loading` | feedback | 旋转 spinner，大(32px)/小(20px) 两种尺寸，含可选文本标签 |
| 进度条 | `progress-bar` | data | 8px 高度轨道，支持 primary/success/warning/error 四种填充色 |
| 列表视图 | `list-view` | list | 分组/简单两种模式，54px 行高，含图标、标题、副标题、尾部信息 |
| 提示条 | `toast` | feedback | 成功/错误两种变体，360px 最大宽度，彩色背景 + 白色文字 |
| 代码块 | `code-block` | code | 等宽字体代码展示，含语言标签 + 复制按钮，圆角 12px |
| 文本输入框 | `text-field` | input | 48px 高度，含标签/图标/错误态，1px 边框 |
| 底部弹窗 | `bottom-sheet` | modal | 底部滑出面板，20px 顶部圆角，36x5 拖拽手柄 |
| 分段控制器 | `segmented-control` | navigation | 32px 轨道高度，2-3 段切换，滑动指示器 |
| 头像 | `avatar` | media | 圆形头像 24/32/48px，含首字母回退和在线状态点 |
| 骨架屏 | `skeleton` | feedback | 加载占位，脉冲动画，含卡片/文本行骨架 |
| 操作菜单 | `action-sheet` | modal | iOS 风格操作表，54px 行高，支持删除态 |
| 图标按钮 | `icon-button` | button | 44px 纯图标按钮，默认/Primary/Ghost 三种样式 |
| 分组标题 | `section-header` | layout | 列表分组标题，13px 600 大写，支持右侧操作链接 |
| 柱状图 | `chart-bar` | data | 垂直柱状图，4px 圆角柱体，支持网格线和轴标签 |
| 饼图 | `pie-chart` | data | CSS conic-gradient 环形图，4 色分段，中心百分比文字 |
| 网页视图 | `web-view` | content | 应用内浏览器，2px 顶部进度条 + URL 栏 + 内容区 |
| 下拉指示器 | `pull-indicator` | feedback | 下拉刷新指示器，箭头/spinner 两种状态 |
| 标签输入 | `chip-input` | input | 标签组/可添加模式，28px pill 标签，6px 间距 |
| 分隔线 | `divider` | layout | 1px 分隔线，全宽或左右缩进 16px |
| 提示气泡 | `tooltip` | feedback | 深色背景 + 浅色文字，6px 圆角，上方/下方两种方向 |
| 警告横幅 | `alert-banner` | feedback | 警告/错误/信息三种语义色，图标 + 文字横幅 |
| 开关卡片 | `switch-card` | input | 设置行 + 图标 + 标题副标题 + 右侧 toggle 开关 |
| 步骤指示器 | `step-indicator` | navigation | 水平步骤条，已完成/活跃/待定三种状态 |
| 滑动操作 | `swipe-action` | gesture | 列表行左滑露出编辑/删除按钮，静止态 + 露出态 |
| 通知横幅 | `notification-banner` | feedback | 应用内通知卡片，纯文字/带头像两种样式 |
| 上下文菜单 | `context-menu` | overlay | 圆角弹出菜单，带图标/纯文字，分组分隔线 |
| 单选组 | `radio-group` | input | 20px 圆形单选指示器，选中态实心圆点 |
| 复选框 | `checkbox` | input | 22px 圆角方形，选中态主色 + 白色勾 |
| 折叠面板 | `accordion` | layout | 可展开/收起，chevron 旋转指示，纯 CSS 切换 |
| 滑块 | `slider` | input | 4px 圆角轨道，24px 圆形拖柄，支持标签和填充色 |
| 用户行 | `user-row` | list | 36px 圆形头像 + 姓名 + 副标题 + 在线状态点 |
| 表单组 | `input-group` | input | 标签 + 描述 + 输入框 + 错误提示，标准/紧凑两种排布 |
| 分页指示器 | `page-dots` | navigation | 6px 圆形点，活跃页 18px 胶囊形 |
| 键值行 | `key-value-row` | data | 左键右值/上键下值，支持等宽字体 code 值 |
| 标签指示器 | `tab-indicator` | navigation | 下划线风格指示器，2-4 标签，30% 宽激活底栏 |
| 媒体行 | `media-row` | list | 44px 缩略图 + 标题 + 副标题 + 时长，紧凑卡片样式 |

更多组件规格参见对应的组件契约 token（`--wbk-button-*`、`--wbk-search-field-*` 等）。

## 使用设计系统

**CSS 方式：**

```css
.my-card {
  background: var(--wbk-surface);
  border-radius: var(--wbk-radius-card);
  padding: var(--wbk-spacing-lg);
  box-shadow: var(--wbk-shadow-card);
  font: var(--wbk-text-body);
  color: var(--wbk-text);
}

.my-button {
  background: var(--wbk-primary);
  color: var(--wbk-text-on-color, #FFFFFF);
  font: var(--wbk-text-button);
  border-radius: var(--wbk-button-corner-radius);
  height: var(--wbk-button-height);
  padding: 0 var(--wbk-button-horizontal-padding);
}
```

**Typography 工具类：**

```html
<h1 class="wbk-text-display-large">页面大标题</h1>
<p class="wbk-text-body">正文内容</p>
<span class="wbk-text-caption">辅助文字</span>
```

**iOS (Swift)：** 使用 `ThemeTokens.Color.*`、`ThemeTokens.Font.*`、`ThemeTokens.Spacing.*`，自动适配 Light/Dark 模式。

## 文件结构

```
.design_library/WebBridgeKit/
├── README.md              ← 本文档
├── colors_and_type.css    ← Token 定义（色彩/排版/间距/圆角/阴影等）
├── components/
│   └── index.json         ← 组件注册清单（52 个组件）
```

## 快速参考

- Token 总数：**162 个**（31 色彩 + 15 排版 + 12 间距 + 12 圆角 + 7 阴影 + 11 图标 + 9 不透明度 + 9 渐变 + 13 动效 + 3 断点 + 39 组件契约 + 1 字体系列）
- 前缀：`--wbk-*`（兼容层：`--color-*`、`--space-*`、`--radius-*` 等）
- 主题：Light（`:root`）+ Dark（`.dark`），支持 `prefers-color-scheme` 自动切换
- 设计来源：`docs/design-tokens.json` v4.0.0
