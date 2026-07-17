/// Display language for the UI.
enum AppLanguage { zh, en }

/// Tiny hand-rolled localization. Avoids the weight/codegen of intl for a
/// two-language app: every string is defined inline as `_(english, chinese)`.
class L10n {
  final AppLanguage lang;
  const L10n(this.lang);

  String _(String en, String zh) => lang == AppLanguage.zh ? zh : en;

  // Header / general
  String get settings => _('Settings', '设置');
  String get cancel => _('Cancel', '取消');
  String get save => _('Save', '保存');
  String get language => _('Language', '语言');

  // Data source
  String get dataSource => _('Data source', '数据源');
  String get sourceManual => _('Manual', '手动');
  String get dbPathLabel =>
      _('cc-switch.db path (blank = default)', 'cc-switch.db 路径（留空=默认）');

  // Anchoring
  String get anchoring => _('Anchoring', '锚定');
  String get perCherry => _('\$ per cherry', '每颗樱桃 \$');
  String get rows => _('Rows', '行');
  String get cols => _('Cols', '列');
  String plateSummary(int n, String total) => _(
        'Plate = $n cherries · \$$total total',
        '一盘 = $n 颗 · 合计 \$$total',
      );

  // Accounting
  String get accounting => _('Accounting', '统计口径');
  String get period => _('Period', '周期');
  String get periodDay => _('Daily (reset at midnight)', '每日（午夜归零）');
  String get periodWeek => _('Weekly', '每周');
  String get periodMonth => _('Monthly', '每月');
  String get periodTotal => _('All time', '全部');
  String get scope => _('Scope', '范围');
  String get scopeGlobal => _('Global (all projects)', '全局（所有项目）');
  String get scopeProject => _('Current project only', '仅当前项目');
  String get projectPathLabel => _('Project path (its cwd)', '项目路径（其 cwd）');

  // Pricing
  String get pricingTitle =>
      _('Pricing (USD per 1M tokens)', '定价（美元 / 每百万 token）');
  String get pricingHelp => _(
        'Set the rate your channel actually bills. Models are matched to a '
            'tier by name; anything unrecognized is priced at \$0 until added.',
        '按你的渠道实际计费来设置。模型按名字归档；无法识别的暂按 0 美元计算，需手动添加价格。',
      );
  String get priceIn => _('In', '输入');
  String get priceOut => _('Out', '输出');
  String get priceCacheRd => _('Cache rd', '缓存读');
  String get priceCacheWr => _('Cache wr', '缓存写');
  String get resetPrices => _('Reset to default prices', '恢复默认价格');
  String get customModels => _('Custom model prices', '自定义模型价格');
  String get customModelsHelp => _(
        'Override pricing for specific models (e.g. gpt-5.5). Matched first by '
            'exact id, then if the model id contains the key.',
        '为特定模型覆盖价格（如 gpt-5.5）。先精确匹配 id，否则匹配「模型 id 包含该关键字」。',
      );
  String get addModel => _('Add model', '添加模型');
  String get modelIdHint => _('model id (e.g. gpt-5.5)', '模型 id（如 gpt-5.5）');

  // Appearance & interaction
  String get appearance => _('Appearance & interaction', '外观与交互');
  String get interaction => _('Default interaction', '默认交互');
  String get interactionDraggable => _('Draggable + hover', '可拖拽 + 悬停');
  String get interactionClickThrough => _('Click-through + tray', '点击穿透 + 托盘');
  String get scale => _('Scale', '缩放');
  String get opacity => _('Opacity', '不透明度');
  String get refresh => _('Refresh', '刷新');

  // Tooltip
  String get today => _('Today', '今日');
  String get thisWeek => _('This week', '本周');
  String get thisMonth => _('This month', '本月');
  String get allTime => _('All time', '全部');
  String get burn => _('burn', '消耗');
  String get cherriesEaten => _('Cherries eaten', '已吃樱桃');
  String plateSuffix(int plateNo) => _(' (plate $plateNo)', '（第 $plateNo 盘）');
  String get perCherryShort => _('\$ / cherry', '每颗 \$');
  String get tokIn => _('Input', '输入');
  String get tokOut => _('Output', '输出');
  String get tokCacheRead => _('Cache read', '缓存读');
  String get tokCacheWrite => _('Cache write', '缓存写');
  String get tokTotal => _('Total tokens', '总 token');

  // Usage warning lights
  String get warningLights => _('Usage lights', '用量告警灯');
  String get currentPlates => _('Current usage', '当前用量');
  String get halfHourSpeed => _('Last 30 min', '近 30 分钟');
  String get dailySpend => _('Today total', '今日总消费');
  String get alertThresholds => _('Warning light thresholds', '告警灯阈值');
  String get maxPlates => _('Usage ceiling', '用量上限');
  String get halfHourTokenLimit => _('30-min token ceiling', '30 分钟 token 上限');
  String get dailyCostLimit => _('Daily cost ceiling', '每日消费上限');
  String get platesUnit => _('plates', '盘');

  // Tray / context menu
  String get enableClickThrough => _('Enable click-through', '开启点击穿透');
  String get disableClickThrough => _('Disable click-through', '关闭点击穿透');
  String get settingsMenu => _('Settings…', '设置…');
  String get quit => _('Quit', '退出');
}
