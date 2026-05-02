(function() {
  var timerId = null;

  function clampScore(value) {
    var number = parseInt(value, 10);
    if (isNaN(number)) return 0;

    return Math.max(0, Math.min(number, 100));
  }

  function optionalScore(value) {
    if (value === null || value === undefined || value === '') return null;

    var number = parseInt(value, 10);
    if (isNaN(number)) return null;

    return Math.max(0, Math.min(number, 100));
  }

  function pointAt(center, radius, angle, score) {
    var scaledRadius = radius * (score / 100);

    return {
      x: center + (Math.cos(angle) * scaledRadius),
      y: center + (Math.sin(angle) * scaledRadius)
    };
  }

  function pointsToString(points) {
    return points.map(function(point) {
      return point.x.toFixed(1) + ',' + point.y.toFixed(1);
    }).join(' ');
  }

  function escapeSvgText(value) {
    return String(value || '').replace(/[&<>"']/g, function(character) {
      return {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#39;'
      }[character];
    });
  }

  function renderChartMessage(target, message) {
    target.innerHTML = '<p class="singing-diagnosis__chart-message">' + escapeSvgText(message) + '</p>';
  }

  function radarItems(target) {
    if (target.dataset.radarItems) {
      try {
        var parsedItems = JSON.parse(target.dataset.radarItems);

        if (Array.isArray(parsedItems)) {
          return parsedItems.map(function(item) {
            return {
              label: item.label,
              score: clampScore(item.score)
            };
          }).filter(function(item) {
            return item.label;
          });
        }
      } catch (error) {
        if (window.console && console.warn) {
          console.warn('[SingingDiagnosisCharts] Failed to parse radar items', error);
        }
        return [];
      }
    }

    return [
      { label: '音程', score: clampScore(target.dataset.pitchScore) },
      { label: 'リズム', score: clampScore(target.dataset.rhythmScore) },
      { label: '表現', score: clampScore(target.dataset.expressionScore) }
    ];
  }

  function buildRadarSvg(target) {
    var items = radarItems(target);
    if (items.length < 3) {
      renderChartMessage(target, 'グラフデータを読み込めませんでした。スコアカードは通常どおり確認できます。');
      return;
    }

    var center = 120;
    var radius = items.length > 3 ? 74 : 86;
    var labelRadius = items.length > 3 ? 105 : 108;
    var angles = items.map(function(_item, index) {
      return ((Math.PI * 2 * index) / items.length) - Math.PI / 2;
    });
    var labels = angles.map(function(angle, index) {
      return {
        text: items[index].label,
        x: center + (Math.cos(angle) * labelRadius),
        y: center + (Math.sin(angle) * labelRadius) + 5
      };
    });
    var scores = items.map(function(item) {
      return item.score;
    });
    var ariaLabel = items.map(function(item) {
      return item.label;
    }).join('、') + 'のレーダーチャート';
    var polygonPoints = scores.map(function(score, index) {
      return pointAt(center, radius, angles[index], score);
    });
    var outerPoints = angles.map(function(angle) {
      return pointAt(center, radius, angle, 100);
    });
    var middlePoints = angles.map(function(angle) {
      return pointAt(center, radius, angle, 66);
    });
    var innerPoints = angles.map(function(angle) {
      return pointAt(center, radius, angle, 33);
    });

    var scoreLabelMarkup = polygonPoints.map(function(point, index) {
      var score = scores[index];
      var offsetX = (point.x - center) * 0.18;
      var offsetY = (point.y - center) * 0.18 - 7;
      return '<text class="singing-diagnosis__radar-score" x="' + (point.x + offsetX).toFixed(1) + '" y="' + (point.y + offsetY).toFixed(1) + '" text-anchor="middle">' + score + '</text>';
    }).join('');

    target.innerHTML = [
      '<svg class="singing-diagnosis__radar-svg" viewBox="0 0 240 240" role="img" aria-label="' + escapeSvgText(ariaLabel) + '">',
      '<rect x="0" y="0" width="240" height="240" rx="10" ry="10" fill="transparent"></rect>',
      '<polygon class="singing-diagnosis__radar-grid" points="' + pointsToString(outerPoints) + '"></polygon>',
      '<polygon class="singing-diagnosis__radar-grid" points="' + pointsToString(middlePoints) + '"></polygon>',
      '<polygon class="singing-diagnosis__radar-grid" points="' + pointsToString(innerPoints) + '"></polygon>',
      outerPoints.map(function(point) {
        return '<line class="singing-diagnosis__radar-axis" x1="' + center + '" y1="' + center + '" x2="' + point.x.toFixed(1) + '" y2="' + point.y.toFixed(1) + '"></line>';
      }).join(''),
      '<polygon class="singing-diagnosis__radar-area" points="' + pointsToString(polygonPoints) + '"></polygon>',
      polygonPoints.map(function(point) {
        return '<circle class="singing-diagnosis__radar-point" cx="' + point.x.toFixed(1) + '" cy="' + point.y.toFixed(1) + '" r="5"></circle>';
      }).join(''),
      labels.map(function(label) {
        return '<text class="singing-diagnosis__radar-label" x="' + label.x.toFixed(1) + '" y="' + label.y.toFixed(1) + '" text-anchor="middle">' + escapeSvgText(label.text) + '</text>';
      }).join(''),
      scoreLabelMarkup,
      '</svg>'
    ].join('');
  }

  function growthItems(target) {
    if (!target.dataset.growthItems) return [];

    try {
      var parsedItems = JSON.parse(target.dataset.growthItems);
      if (!Array.isArray(parsedItems)) return [];

      return parsedItems.map(function(item) {
        var mappedItem = {
          label: item.label || '',
          overall_score: optionalScore(item.overall_score),
          pitch_score: optionalScore(item.pitch_score),
          rhythm_score: optionalScore(item.rhythm_score),
          expression_score: optionalScore(item.expression_score),
          volume_score: optionalScore(item.volume_score),
          pronunciation_score: optionalScore(item.pronunciation_score),
          relax_score: optionalScore(item.relax_score),
          mix_voice_score: optionalScore(item.mix_voice_score),
          attack_score: optionalScore(item.attack_score),
          muting_score: optionalScore(item.muting_score),
          stability_score: optionalScore(item.stability_score),
          groove_score: optionalScore(item.groove_score),
          note_length_score: optionalScore(item.note_length_score),
          tempo_stability_score: optionalScore(item.tempo_stability_score),
          rhythm_precision_score: optionalScore(item.rhythm_precision_score),
          dynamics_score: optionalScore(item.dynamics_score),
          fill_control_score: optionalScore(item.fill_control_score),
          chord_stability_score: optionalScore(item.chord_stability_score),
          note_connection_score: optionalScore(item.note_connection_score),
          touch_score: optionalScore(item.touch_score),
          harmony_score: optionalScore(item.harmony_score)
        };

        Object.keys(item).forEach(function(key) {
          if (key === 'label' || Object.prototype.hasOwnProperty.call(mappedItem, key)) return;

          mappedItem[key] = optionalScore(item[key]);
        });

        return mappedItem;
      });
    } catch (error) {
      if (window.console && console.warn) {
        console.warn('[SingingDiagnosisCharts] Failed to parse growth items', error);
      }
      return [];
    }
  }

  function growthSeries(target) {
    if (!target.dataset.growthSeries) return [];

    try {
      var parsedSeries = JSON.parse(target.dataset.growthSeries);
      if (!Array.isArray(parsedSeries)) return [];

      return parsedSeries.filter(function(series) {
        return series && series.key && series.label && series.color;
      });
    } catch (error) {
      if (window.console && console.warn) {
        console.warn('[SingingDiagnosisCharts] Failed to parse growth series', error);
      }
      return [];
    }
  }

  function linePoints(items, seriesKey, chartWidth, chartHeight, padding) {
    var usableWidth = chartWidth - (padding * 2);
    var usableHeight = chartHeight - (padding * 2);

    return items.map(function(item, index) {
      var x = items.length === 1 ? chartWidth / 2 : padding + ((usableWidth * index) / (items.length - 1));
      var score = optionalScore(item[seriesKey]);
      var y = score === null ? null : padding + (usableHeight * (1 - (score / 100)));

      return { x: x, y: y, score: score };
    });
  }

  function pointsToSegments(points) {
    var segments = [];
    var currentSegment = [];

    points.forEach(function(point) {
      if (point.score === null || point.y === null) {
        if (currentSegment.length > 0) {
          segments.push(currentSegment);
          currentSegment = [];
        }
        return;
      }

      currentSegment.push(point);
    });

    if (currentSegment.length > 0) {
      segments.push(currentSegment);
    }

    return segments;
  }

  function buildGrowthSvg(target) {
    var items = growthItems(target);
    var series = growthSeries(target);
    if (items.length === 0 || series.length === 0) {
      renderChartMessage(target, 'グラフデータを読み込めませんでした。診断結果は通常どおり確認できます。');
      return;
    }

    var width = 520;
    var height = 260;
    var padding = 34;
    var axisLeft = padding;
    var axisBottom = height - padding;
    var axisRight = width - padding;
    var axisTop = padding;
    var gridValues = [0, 25, 50, 75, 100];

    var lineMarkup = series.map(function(config) {
      var points = linePoints(items, config.key, width, height, padding);
      var segments = pointsToSegments(points);
      var validPoints = points.filter(function(point) { return point.score !== null; });
      var lastPoint = validPoints[validPoints.length - 1] || null;

      var pointMarkup = validPoints.map(function(point) {
        return '<circle cx="' + point.x.toFixed(1) + '" cy="' + point.y.toFixed(1) + '" r="4" fill="' + config.color + '" stroke="rgba(14,24,41,0.8)" stroke-width="1.5"></circle>';
      }).join('');

      var lastLabelMarkup = lastPoint
        ? '<text class="singing-diagnosis__growth-point-label" x="' + lastPoint.x.toFixed(1) + '" y="' + (lastPoint.y - 9).toFixed(1) + '" text-anchor="middle" fill="' + config.color + '">' + lastPoint.score + '</text>'
        : '';

      var polylineMarkup = segments.map(function(segment) {
        return '<polyline class="singing-diagnosis__growth-line" fill="none" stroke="' + config.color + '" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" points="' + pointsToString(segment) + '"></polyline>';
      }).join('');

      return [polylineMarkup, pointMarkup, lastLabelMarkup].join('');
    }).join('');

    var labelMarkup = items.map(function(item, index) {
      var x = items.length === 1 ? width / 2 : padding + (((width - (padding * 2)) * index) / (items.length - 1));
      return '<text class="singing-diagnosis__growth-label" x="' + x.toFixed(1) + '" y="' + (height - 10) + '" text-anchor="middle">' + escapeSvgText(item.label) + '</text>';
    }).join('');

    var gridMarkup = gridValues.map(function(value) {
      var y = padding + ((height - (padding * 2)) * (1 - (value / 100)));
      return [
        '<line class="singing-diagnosis__growth-grid" x1="' + axisLeft + '" y1="' + y.toFixed(1) + '" x2="' + axisRight + '" y2="' + y.toFixed(1) + '"></line>',
        '<text class="singing-diagnosis__growth-axis-label" x="10" y="' + (y + 4).toFixed(1) + '">' + value + '</text>'
      ].join('');
    }).join('');

    target.innerHTML = [
      '<svg class="singing-diagnosis__growth-svg" viewBox="0 0 ' + width + ' ' + height + '" role="img" aria-label="成長推移グラフ">',
      gridMarkup,
      '<line class="singing-diagnosis__growth-axis" x1="' + axisLeft + '" y1="' + axisTop + '" x2="' + axisLeft + '" y2="' + axisBottom + '"></line>',
      '<line class="singing-diagnosis__growth-axis" x1="' + axisLeft + '" y1="' + axisBottom + '" x2="' + axisRight + '" y2="' + axisBottom + '"></line>',
      lineMarkup,
      labelMarkup,
      '</svg>'
    ].join('');
  }

  function renderRadarCharts() {
    var targets = document.querySelectorAll('[data-singing-diagnosis-radar]');

    Array.prototype.forEach.call(targets, function(target) {
      buildRadarSvg(target);
    });
  }

  function renderGrowthCharts() {
    var targets = document.querySelectorAll('[data-singing-diagnosis-growth]');

    Array.prototype.forEach.call(targets, function(target) {
      buildGrowthSvg(target);
    });
  }

  var navMenuOpen = false;

  function openSingingNav() {
    var menu = document.querySelector('[data-singing-nav-mobile]');
    var toggle = document.querySelector('[data-singing-nav-toggle]');
    if (!menu || !toggle) return;

    menu.classList.add('singing-nav__mobile-menu--open');
    toggle.setAttribute('aria-expanded', 'true');
    navMenuOpen = true;
  }

  function closeSingingNav() {
    var menu = document.querySelector('[data-singing-nav-mobile]');
    var toggle = document.querySelector('[data-singing-nav-toggle]');
    if (!menu || !toggle) return;

    menu.classList.remove('singing-nav__mobile-menu--open');
    toggle.setAttribute('aria-expanded', 'false');
    navMenuOpen = false;
  }

  function initSingingNav() {
    var toggle = document.querySelector('[data-singing-nav-toggle]');
    var overlay = document.querySelector('[data-singing-nav-overlay]');
    if (!toggle) return;

    toggle.addEventListener('click', function() {
      navMenuOpen ? closeSingingNav() : openSingingNav();
    });

    if (overlay) {
      overlay.addEventListener('click', closeSingingNav);
    }
  }

  function stopPolling() {
    if (!timerId) return;

    clearInterval(timerId);
    timerId = null;
  }

  function startPolling() {
    stopPolling();

    var target = document.querySelector('[data-singing-diagnosis-polling]');
    if (!target) return;

    var interval = parseInt(target.dataset.singingDiagnosisPollingInterval, 10) || 5000;

    timerId = setInterval(function() {
      window.location.reload();
    }, interval);
  }

  function initDiagnosisCharts() {
    startPolling();
    renderRadarCharts();
    renderGrowthCharts();
    initSingingNav();
  }

  document.addEventListener('DOMContentLoaded', initDiagnosisCharts);
  document.addEventListener('turbolinks:load', initDiagnosisCharts);
  document.addEventListener('turbolinks:before-cache', function() {
    stopPolling();
    closeSingingNav();
  });
  window.addEventListener('pagehide', stopPolling);
})();
