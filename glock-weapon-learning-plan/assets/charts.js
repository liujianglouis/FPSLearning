// 页面脚本：Mermaid 初始化 + ECharts 图表
// 所有颜色都从 CSS 变量读取，保持与页面主题一致
(function () {
  // ---------- Mermaid：数值框架图 ----------
  if (window.mermaid) {
    mermaid.initialize({ startOnLoad: true, theme: 'neutral', securityLevel: 'loose' });
  }

  // ---------- 读取主题色 ----------
  var style = getComputedStyle(document.documentElement);
  var accent = style.getPropertyValue('--accent').trim();
  var accent2 = style.getPropertyValue('--accent2').trim();
  var ink = style.getPropertyValue('--ink').trim();
  var muted = style.getPropertyValue('--muted').trim();
  var rule = style.getPropertyValue('--rule').trim();

  var el = document.getElementById('chart-recoil');
  if (!el || !window.echarts) {
    return;
  }

  // ---------- 图 2：分段后坐力骨架 ----------
  // 落点 = [水平偏移(度, 右为正), 垂直累积(度), 第几发]
  // 骨架形状（示意）：1-3 发均匀向上 → 4-7 发向上逐渐加大
  //                → 8-10 发向左上 45° 偏移 → 11 发起垂直封顶，只吃水平
  //                → 17 发达到最大水平后，落点只受子弹散布影响
  var pattern = [
    [0.10, 0.8, 1], [-0.20, 1.7, 2], [0.15, 2.6, 3],
    [-0.10, 3.7, 4], [0.20, 4.9, 5], [-0.15, 6.2, 6], [0.10, 7.6, 7],
    [-0.60, 9.0, 8], [-1.10, 10.2, 9], [-1.50, 11.3, 10],
    [-1.30, 12.0, 11], [-0.90, 12.0, 12], [-0.30, 12.0, 13],
    [0.40, 12.0, 14], [1.20, 12.0, 15], [2.00, 12.0, 16], [2.60, 12.0, 17],
    [2.40, 12.0, 18]
  ];

  var chart = echarts.init(el, null, { renderer: 'svg' });
  chart.setOption({
    animation: false,
    grid: { left: 74, right: 54, top: 34, bottom: 60 },
    tooltip: {
      trigger: 'item',
      appendToBody: true,
      formatter: function (p) {
        return '第 ' + p.data[2] + ' 发<br/>垂直累积：' + p.data[1].toFixed(1) + '°<br/>水平偏移：' + p.data[0].toFixed(2) + '°';
      }
    },
    xAxis: {
      type: 'value',
      name: '水平偏移（度，右为正）',
      nameLocation: 'middle',
      nameGap: 32,
      min: -2.6,
      max: 3.4,
      nameTextStyle: { color: muted, fontSize: 12 },
      axisLine: { lineStyle: { color: rule } },
      axisTick: { show: false },
      axisLabel: { color: muted, fontSize: 12 },
      splitLine: { lineStyle: { color: rule } }
    },
    yAxis: {
      type: 'value',
      name: '垂直累积（度）',
      nameGap: 18,
      min: 0,
      max: 14,
      nameTextStyle: { color: muted, fontSize: 12 },
      axisLine: { show: false },
      axisTick: { show: false },
      axisLabel: { color: muted, fontSize: 12 },
      splitLine: { lineStyle: { color: rule } }
    },
    series: [
      {
        type: 'line',
        data: pattern,
        symbol: 'circle',
        symbolSize: 9,
        itemStyle: { color: accent2 },
        lineStyle: { width: 1.5, type: 'dashed', color: accent + '80' },
        label: {
          show: true,
          position: 'right',
          distance: 6,
          formatter: function (p) { return p.data[2]; },
          color: muted,
          fontSize: 10,
          fontFamily: 'JetBrains Mono, monospace'
        },
        markLine: {
          silent: true,
          symbol: 'none',
          lineStyle: { color: accent, type: 'dashed', width: 1 },
          label: {
            formatter: '极限后坐力',
            position: 'insideEndTop',
            color: accent,
            fontSize: 11
          },
          data: [{ yAxis: 12 }]
        }
      }
    ]
  });

  window.addEventListener('resize', function () {
    chart.resize();
  });
})();
