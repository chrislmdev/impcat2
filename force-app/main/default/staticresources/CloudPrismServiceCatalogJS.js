(function () {
  "use strict";

  var TOP_N = 3;
  var csoPricingData = [];

  var csOParentServiceData = [];

  /** Called from Visualforce after RemoteAction loads JSON (works inside Lightning iframes). */
  window.initCloudPrismServiceCatalog = function (jsonString) {
    try {
      csOParentServiceData = JSON.parse(jsonString || "[]");
    } catch (e) {
      csOParentServiceData = [];
    }
    populateCats();
    renderServices();
  };

  var CAT_ICONS = {
    Compute:
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="2" y="3" width="20" height="14" rx="2"/><path d="M8 21h8M12 17v4"/></svg>',
    Storage:
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M21 12c0 1.66-4.03 3-9 3S3 13.66 3 12"/><path d="M3 5v14c0 1.66 4.03 3 9 3s9-1.34 9-3V5"/></svg>',
    Database:
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M21 12c0 1.66-4.03 3-9 3S3 13.66 3 12"/><path d="M3 5v14c0 1.66 4.03 3 9 3s9-1.34 9-3V5"/></svg>',
    Networking:
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="12" r="10"/><path d="M2 12h20M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/></svg>',
    "AI and Machine Learning":
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M12 2a4 4 0 0 1 4 4v1h1a3 3 0 0 1 0 6h-1v1a4 4 0 0 1-8 0v-1H7a3 3 0 0 1 0-6h1V6a4 4 0 0 1 4-4z"/><circle cx="9" cy="9" r="1" fill="currentColor"/><circle cx="15" cy="9" r="1" fill="currentColor"/></svg>',
    Security:
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>',
    Integration:
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><polyline points="16 3 21 3 21 8"/><line x1="4" y1="20" x2="21" y2="3"/><polyline points="21 16 21 21 16 21"/><line x1="15" y1="15" x2="21" y2="21"/></svg>',
    Analytics:
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><line x1="18" y1="20" x2="18" y2="10"/><line x1="12" y1="20" x2="12" y2="4"/><line x1="6" y1="20" x2="6" y2="14"/></svg>',
    "Developer Tools":
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/></svg>',
    "Management and Governance":
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="12" r="3"/><path d="M19.07 4.93a10 10 0 0 0-14.14 0M4.93 19.07a10 10 0 0 0 14.14 0M1 12H3M21 12h2M12 1v2M12 21v2"/></svg>',
    "Internet of Things":
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="12" r="3"/><path d="M6.3 6.3a8 8 0 0 0 0 11.4M17.7 6.3a8 8 0 0 1 0 11.4M3.5 3.5a13 13 0 0 0 0 17M20.5 3.5a13 13 0 0 1 0 17"/></svg>',
    Migration:
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M5 12h14M12 5l7 7-7 7"/></svg>',
    "End User Computing":
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="2" y="3" width="20" height="14" rx="2"/><path d="M8 21h8M12 17v4"/><path d="M9 8l2 2 4-4"/></svg>',
    "Professional Services":
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>',
    Other:
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>',
  };

  function catIcon(cat) {
    var svg = CAT_ICONS[cat] || CAT_ICONS.Other;
    return '<span class="cat-icon">' + svg + "</span>";
  }

  var msState = { cat: new Set(), il: new Set(), csp: new Set() };
  var msLabels = {
    cat: { default: "All categories", plural: "Categories" },
    il: { default: "All levels", plural: "Impact levels" },
    csp: { default: "All CSPs", plural: "CSPs" },
  };

  function toggleMs(key) {
    var drop = document.getElementById("ms-" + key + "-drop");
    var btn = document.getElementById("ms-" + key + "-btn");
    if (!drop || !btn) return;
    var isOpen = drop.classList.contains("open");
    document.querySelectorAll(".ms-dropdown").forEach(function (d) {
      d.classList.remove("open");
    });
    document.querySelectorAll(".ms-btn").forEach(function (b) {
      b.classList.remove("open");
    });
    if (!isOpen) {
      drop.classList.add("open");
      btn.classList.add("open");
    }
  }

  function toggleMsOpt(key, val, el) {
    if (msState[key].has(val)) msState[key].delete(val);
    else msState[key].add(val);
    el.classList.toggle("selected", msState[key].has(val));
    updateMsLabel(key);
    renderServices();
  }

  function clearMs(key) {
    msState[key].clear();
    document.querySelectorAll('[data-ms="' + key + '"]').forEach(function (el) {
      el.classList.remove("selected");
    });
    updateMsLabel(key);
    renderServices();
  }

  function updateMsLabel(key) {
    var s = msState[key];
    var lbl = document.getElementById("ms-" + key + "-label");
    var btn = document.getElementById("ms-" + key + "-btn");
    if (!lbl || !btn) return;
    var old = btn.querySelector(".ms-count");
    if (old) old.remove();
    if (s.size === 0) {
      lbl.textContent = msLabels[key].default;
    } else {
      lbl.textContent = s.size === 1 ? Array.from(s)[0] : msLabels[key].plural;
      var badge = document.createElement("span");
      badge.className = "ms-count";
      badge.textContent = String(s.size);
      btn.insertBefore(badge, btn.querySelector(".ms-arrow"));
    }
  }

  window.toggleMs = toggleMs;
  window.toggleMsOpt = toggleMsOpt;
  window.clearMs = clearMs;

  document.addEventListener("click", function (e) {
    if (!e.target.closest(".ms-wrap")) {
      document.querySelectorAll(".ms-dropdown").forEach(function (d) {
        d.classList.remove("open");
      });
      document.querySelectorAll(".ms-btn").forEach(function (b) {
        b.classList.remove("open");
      });
    }
  });

  function resolveServiceCatalogGroupDescription(g) {
    var allRows = []
      .concat(g.aws || [], g.azure || [], g.gcp || [], g.oracle || []);
    var direct = allRows.find(function (r) {
      return String(r.description || "").trim();
    });
    if (direct) return String(direct.description).trim();

    var pricing = Array.isArray(csoPricingData) ? csoPricingData : [];
    var normC = function (v) {
      return String(v || "")
        .toLowerCase()
        .trim();
    };
    if (pricing.length) {
      for (var ci = 0; ci < ["aws", "azure", "gcp", "oracle"].length; ci++) {
        var csp = ["aws", "azure", "gcp", "oracle"][ci];
        var rows = g[csp];
        if (!rows || !rows.length) continue;
        for (var i = 0; i < rows.length; i++) {
          var s = rows[i];
          var num = String(s.catalogitemnumber || s.catalogitemNumber || "").trim();
          var c = normC(s.csp_injected || s.csp);
          if (!num || !c) continue;
          var pr = pricing.find(function (p) {
            return (
              normC(p.csp_injected || p.csp) === c &&
              String(p.catalogitemnumber || "").trim() === num
            );
          });
          if (pr) {
            var d = String(pr.description || "").trim();
            if (d) return d;
            var t = String(pr.title || "").trim();
            if (t) return t;
          }
        }
      }
    }
    var any = allRows[0];
    if (!any) return "—";
    var p = String(any.csoparentservice || any.csOParentService || "").trim();
    if (p) return p;
    var sh = String(any.csoshortname || any.csoShortName || "").trim();
    if (sh) return sh;
    return "—";
  }

  function buildBadges(svcs) {
    if (!svcs || !svcs.length) return '<span class="none-ind">—</span>';
    return svcs
      .map(function (s) {
        var nameHtml = s.url
          ? '<a href="' +
            s.url +
            '" target="_blank" rel="noopener">' +
            s.name +
            "</a>"
          : s.name;
        var newHtml = s.newService ? ' <span class="nb">✦</span>' : "";
        var ilHtml = (s.il || [])
          .map(function (l) {
            var c =
              l === "IL5" && s.newlyAuthorizedIL5 ? "il-IL5-new" : "il-" + l;
            return '<span class="ib ' + c + '">' + l + "</span>";
          })
          .join("");
        return (
          '<div class="se"><div class="sn">' +
          nameHtml +
          newHtml +
          '</div><div class="sm">' +
          ilHtml +
          "</div></div>"
        );
      })
      .join("");
  }

  function dedupeParentServiceRows(arr) {
    var norm = function (t) {
      return String(t || "")
        .toLowerCase()
        .replace(/\s+/g, " ")
        .trim();
    };
    var seen = new Set();
    var out = [];
    var anon = 0;
    for (var i = 0; i < arr.length; i++) {
      var s = arr[i];
      var csp = String(s.csp_injected || s.csp || "")
        .toLowerCase()
        .trim();
      var cat = String(s.catalogitemnumber || "").trim();
      var shortN = norm(s.csoshortname || s.csoShortName || "");
      var parent = norm(s.csoparentservice || s.csOParentService || "");
      var k;
      if (cat) {
        k = csp + "|cat:" + cat.toLowerCase();
      } else {
        var pair = [shortN, parent].filter(Boolean).sort();
        if (pair.length >= 2) k = csp + "|nm:" + pair[0] + "|" + pair[1];
        else if (pair.length === 1) k = csp + "|nm:" + pair[0];
        else k = csp + "|row:" + anon++;
      }
      if (seen.has(k)) continue;
      seen.add(k);
      out.push(s);
    }
    return out;
  }

  function resolveFocusCategory(s) {
    return (
      String(s.focus_category || s.category || s.Category || "Other").trim() ||
      "Other"
    );
  }

  function resolveComparisonSubcategory(s) {
    return (
      String(
        s.comparison_subcategory ||
          s.csoshortname ||
          s.csoShortName ||
          s.csoparentservice ||
          s.csOParentService ||
          "Other offerings"
      ).trim() || "Other offerings"
    );
  }

  var svcSortCol = "category";
  var svcSortDir = 1;
  var SVC_IL_ORDER = ["IL2", "IL3", "IL4", "IL5", "IL6"];

  function sortIlSet(ilObj) {
    var ordered = SVC_IL_ORDER.filter(function (x) {
      return ilObj[x];
    });
    var rest = Object.keys(ilObj)
      .filter(function (x) {
        return SVC_IL_ORDER.indexOf(x) < 0;
      })
      .sort();
    return ordered.concat(rest);
  }

  function rowsForCellBadges(svcs) {
    var sorted = svcs.slice().sort(function (a, b) {
      return (
        Number(b.popularityscore != null ? b.popularityscore : 0) -
        Number(a.popularityscore != null ? a.popularityscore : 0)
      );
    });
    var normKey = function (t) {
      return String(t || "")
        .toLowerCase()
        .replace(/\s+/g, " ")
        .trim();
    };
    var byName = {};
    var order = [];
    for (var i = 0; i < sorted.length; i++) {
      var s = sorted[i];
      var name = String(
        s.csoparentservice || s.csOParentService || s.csoshortname || ""
      ).trim();
      var nk = normKey(name) || "__anon";
      var rawIL = s.impactlevel || s.ImpactLevel || "";
      var levels = String(rawIL)
        .split("|")
        .map(function (l) {
          return l.trim().toUpperCase();
        })
        .filter(Boolean);
      if (!byName[nk]) {
        byName[nk] = {
          name: name || "Unknown",
          ils: {},
          newService: !!(s.newservice || s.newService),
          newlyAuthorizedIL5: !!(s.newlyauthorizedil5 || s.newlyAuthorizedIL5),
        };
        order.push(nk);
      }
      var g = byName[nk];
      for (var li = 0; li < levels.length; li++) {
        g.ils[levels[li]] = true;
      }
      if (s.newservice || s.newService) g.newService = true;
      if (s.newlyauthorizedil5 || s.newlyAuthorizedIL5) g.newlyAuthorizedIL5 = true;
    }
    return order.map(function (nk) {
      var row = byName[nk];
      return {
        name: row.name,
        il: sortIlSet(row.ils),
        newService: row.newService,
        newlyAuthorizedIL5: row.newlyAuthorizedIL5,
      };
    });
  }

  window.toggleSvcMore = function (btn) {
    var w = btn.nextElementSibling;
    if (!w) return;
    var open = w.hasAttribute("hidden");
    if (open) w.removeAttribute("hidden");
    else w.setAttribute("hidden", "hidden");
    btn.setAttribute("aria-expanded", open ? "true" : "false");
    var n = w.querySelectorAll(".se").length;
    btn.textContent = open ? "Show less" : "+" + n + " more";
  };

  function renderCspCellGroup(svcs) {
    if (!svcs || !svcs.length) return '<span class="none-ind">·</span>';
    var merged = rowsForCellBadges(svcs);
    if (merged.length <= TOP_N) return buildBadges(merged);
    var more = merged.length - TOP_N;
    return (
      buildBadges(merged.slice(0, TOP_N)) +
      '<button type="button" class="svc-more-btn" onclick="toggleSvcMore(this)" aria-expanded="false">+' +
      more +
      ' more</button><div class="svc-more-wrap" hidden>' +
      buildBadges(merged.slice(TOP_N)) +
      "</div>"
    );
  }

  window.toggleSvcCatBand = function (tr) {
    if (!tr || !tr.classList.contains("svc-cat-band")) return;
    var cid = tr.getAttribute("data-cid");
    var collapsed = tr.classList.toggle("cat-collapsed");
    document.querySelectorAll('tr.svc-data-row[data-cid="' + cid + '"]').forEach(function (row) {
      row.style.display = collapsed ? "none" : "";
    });
    var chev = tr.querySelector(".svc-cat-chev");
    if (chev) {
      chev.textContent = collapsed ? "▸" : "▾";
      chev.setAttribute("aria-expanded", collapsed ? "false" : "true");
    }
  };

  function renderServices() {
    var query =
      (document.getElementById("svcSearch") &&
        document.getElementById("svcSearch").value.toLowerCase()) ||
      "";
    var body = document.getElementById("svcBody");
    var meta = document.getElementById("svcMeta");
    if (!body) return;

    var data =
      csOParentServiceData.length > 0
        ? dedupeParentServiceRows(csOParentServiceData)
        : [];
    if (!data.length) {
      body.innerHTML = "";
      var svcEmpty0 = document.getElementById("svcEmpty");
      if (svcEmpty0) svcEmpty0.style.display = "none";
      if (meta)
        meta.innerHTML =
          "No catalog rows returned. Add <strong>Service_Catalog_Entry__c</strong> data or check permissions.";
      return;
    }

    var grouped = {};
    data.forEach(function (s) {
      var cat = resolveFocusCategory(s);
      var sub = resolveComparisonSubcategory(s);
      var key = (cat + "|" + sub).toLowerCase().trim();

      if (!grouped[key]) {
        grouped[key] = {
          category: cat,
          subcategoryLabel: sub,
          description: "",
          aws: [],
          azure: [],
          gcp: [],
          oracle: [],
        };
      }

      var provider = String(s.csp_injected || s.csp || "")
        .toLowerCase()
        .trim();
      if (provider && grouped[key][provider]) {
        grouped[key][provider].push(s);
      }
    });

    Object.keys(grouped).forEach(function (k) {
      grouped[k].description = resolveServiceCatalogGroupDescription(grouped[k]);
    });

    var flat = Object.keys(grouped).map(function (k) {
      return grouped[k];
    });
    var svcEmpty = document.getElementById("svcEmpty");

    var filtered = flat.filter(function (g) {
      var qLower = query.toLowerCase();
      var subLbl = (g.subcategoryLabel || "").toLowerCase();
      var descL = (g.description || "").toLowerCase();
      var nameBlobParts = [];
      ["aws", "azure", "gcp", "oracle"].forEach(function (csp) {
        (g[csp] || []).forEach(function (r) {
          nameBlobParts.push(
            (r.csoparentservice || r.csOParentService || "") +
              " " +
              (r.csoshortname || r.csoShortName || "") +
              " " +
              (r.description || "")
          );
        });
      });
      var nameBlob = nameBlobParts.join(" ").toLowerCase();
      var matchQuery =
        !query ||
        g.category.toLowerCase().includes(qLower) ||
        subLbl.includes(qLower) ||
        descL.includes(qLower) ||
        nameBlob.includes(qLower);
      var matchCat =
        msState.cat.size === 0 || msState.cat.has(g.category);

      var matchIL =
        msState.il.size === 0 ||
        ["aws", "azure", "gcp", "oracle"].some(function (csp) {
          return g[csp].some(function (s) {
            var levels = String(s.impactlevel || s.ImpactLevel || "")
              .split("|")
              .map(function (l) {
                return l.trim().toUpperCase();
              });
            return levels.some(function (lv) {
              return msState.il.has(lv);
            });
          });
        });

      var matchCSP =
        msState.csp.size === 0 ||
        ["aws", "azure", "gcp", "oracle"].some(function (csp) {
          return msState.csp.has(csp) && g[csp].length > 0;
        });
      return matchQuery && matchCat && matchIL && matchCSP;
    });

    if (!filtered.length) {
      body.innerHTML = "";
      if (svcEmpty) svcEmpty.style.display = "block";
      if (meta)
        meta.innerHTML = flat.length
          ? "No rows match your filters."
          : "No mapping data loaded.";
      return;
    }
    if (svcEmpty) svcEmpty.style.display = "none";

    var subDisp = function (g) {
      return g.subcategoryLabel || "—";
    };
    var byCat = {};
    filtered.forEach(function (g) {
      if (!byCat[g.category]) byCat[g.category] = [];
      byCat[g.category].push(g);
    });
    var catsOrdered = Object.keys(byCat);
    catsOrdered.sort(function (a, b) {
      return a.localeCompare(b);
    });
    if (svcSortCol === "category" && svcSortDir < 0) catsOrdered.reverse();

    catsOrdered.forEach(function (cat) {
      var list = byCat[cat];
      if (svcSortCol === "subcategory") {
        list.sort(function (a, b) {
          return subDisp(a).localeCompare(subDisp(b)) * svcSortDir;
        });
      } else {
        list.sort(function (a, b) {
          return subDisp(a).localeCompare(subDisp(b));
        });
      }
    });

    var rowsHtml = [];
    var catIdx = 0;
    for (var ci = 0; ci < catsOrdered.length; ci++) {
      var cat = catsOrdered[ci];
      var list = byCat[cat];
      var cid = "c" + catIdx++;
      rowsHtml.push(
        '<tr class="svc-cat-band" data-cid="' +
          cid +
          '" onclick="toggleSvcCatBand(this)"><td colspan="7"><div class="svc-cat-band-inner"><button type="button" class="svc-cat-chev" aria-expanded="true" onclick="event.stopPropagation();toggleSvcCatBand(this.closest(\'tr\'))">▾</button>' +
          catIcon(cat) +
          "<span>" +
          cat +
          "</span></div></td></tr>"
      );
      for (var j = 0; j < list.length; j++) {
        var g = list[j];
        rowsHtml.push(
          '<tr class="svc-data-row" data-cid="' +
            cid +
            '"><td class="td-cat"><span style="display:flex;align-items:center;gap:5px">' +
            catIcon(g.category) +
            g.category +
            '</span></td><td class="td-sub">' +
            subDisp(g) +
            '</td><td class="td-desc">' +
            g.description +
            '</td><td class="svc-cell td-aws-c">' +
            renderCspCellGroup(g.aws) +
            '</td><td class="svc-cell td-azure-c">' +
            renderCspCellGroup(g.azure) +
            '</td><td class="svc-cell td-gcp-c">' +
            renderCspCellGroup(g.gcp) +
            '</td><td class="svc-cell td-oracle-c">' +
            renderCspCellGroup(g.oracle) +
            "</td></tr>"
        );
      }
    }
    body.innerHTML = rowsHtml.join("");

    if (meta) {
      var ucat = {};
      for (var fi = 0; fi < filtered.length; fi++) {
        ucat[filtered[fi].category] = 1;
      }
      var ncat = 0;
      for (var ck in ucat) {
        if (Object.prototype.hasOwnProperty.call(ucat, ck)) ncat++;
      }
      meta.innerHTML =
        "Showing <strong>" +
        filtered.length +
        "</strong> comparison rows in <strong>" +
        ncat +
        "</strong> FOCUS categories (" +
        flat.length +
        " total groups) · Salesforce data";
    }
  }

  window.renderServices = renderServices;

  function populateCats() {
    var data = csOParentServiceData.length > 0 ? csOParentServiceData : [];
    var seen = {};
    var cats = [];
    for (var di = 0; di < data.length; di++) {
      var c0 = resolveFocusCategory(data[di]);
      if (!seen[c0]) {
        seen[c0] = true;
        cats.push(c0);
      }
    }
    cats.sort();
    var container = document.getElementById("ms-cat-opts");
    if (!container) return;
    container.innerHTML = cats
      .map(function (c) {
        return (
          '<div class="ms-option" data-ms="cat"><span class="ms-check"></span>' +
          catIcon(c) +
          "<span></span></div>"
        );
      })
      .join("");
    var opts = container.querySelectorAll(".ms-option");
    for (var i = 0; i < opts.length; i++) {
      (function (cat, el) {
        var label = el.querySelector("span:last-child");
        if (label) label.textContent = cat;
        el.addEventListener("click", function () {
          toggleMsOpt("cat", cat, el);
        });
      })(cats[i], opts[i]);
    }
  }

  document.addEventListener("DOMContentLoaded", function () {
    document.querySelectorAll(".sortable").forEach(function (th) {
      th.addEventListener("click", function () {
        var col = th.dataset.col;
        svcSortDir = svcSortCol === col ? -svcSortDir : 1;
        svcSortCol = col;
        document.querySelectorAll(".sortable").forEach(function (t) {
          t.classList.remove("sorted");
          var si = t.querySelector(".si");
          if (si) si.textContent = "↕";
        });
        th.classList.add("sorted");
        var si2 = th.querySelector(".si");
        if (si2) si2.textContent = svcSortDir === 1 ? "↑" : "↓";
        renderServices();
      });
    });
  });
})();
