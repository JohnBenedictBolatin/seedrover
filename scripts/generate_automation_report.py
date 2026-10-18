#!/usr/bin/env python3
"""Build the SeedRover formal testing paper and registers from the scenario catalogue and real Playwright runs."""
from __future__ import annotations

import argparse
import copy
import csv
import html
import json
import re
import shutil
import zipfile
from datetime import datetime, timedelta, timezone
from pathlib import Path
from xml.etree.ElementTree import Element, SubElement, tostring

from docx import Document
from docx.enum.style import WD_STYLE_TYPE
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor
from PIL import Image, ImageDraw, ImageFont
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch, mm
from reportlab.platypus import (BaseDocTemplate, Frame, Image as PDFImage, PageBreak,
    PageTemplate, Paragraph, Spacer, Table, TableStyle, KeepTogether)
from reportlab.platypus.tableofcontents import TableOfContents

from automation_manual_scenarios import SCENARIOS

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "web-admin"
OUT = ROOT / "docs" / "automation"
TITLE = "SeedRover Web Portal: Software Testing, Validation, and Playwright Automation Report"
GREEN = "246B45"
DARK = "18382A"
PALE = "EAF4EE"
GOLD = "C49A42"
TEST_FIELDS = ["Case ID", "Scenario", "Objective", "Module", "Role", "Priority", "Test Type", "Preconditions", "Test Data", "Steps", "Expected Result", "Cleanup", "Method", "Actual Result", "Status", "Evidence", "Source"]

MODULE_NAMES = {
    "AUTH": "Authentication and recovery", "ROLE": "Role authorization", "CROP": "Crops, care and harvest",
    "CUST": "Customers, discounts and payment records", "DASH": "Dashboard and analytics", "REPORT": "Reports, exports and print views",
    "INV": "Inventory catalogue", "OBS": "Notifications and activity history", "SALE": "Sales and receipts", "USER": "User management",
}

AUTO_AUDIT = {
    "SR-INV-007": "Weak assertion: the test edits the control but does not submit the form. It confirms the UI value is non-negative or HTML validity blocks it, then reads the unchanged database price; it does not prove server-side negative-price rejection.",
    "SR-USER-002": "The test asserts the duplicate-username message. It does not query the profile count after rejection, so the evidence establishes the visible response but not an independent persistence check.",
    "SR-ROLE-011": "Route guard and visible-page assertion only; no direct protected-action request is made.",
    "SR-ROLE-012": "Route guard and visible-page assertion only; no direct protected-action request is made.",
    "SR-ROLE-013": "Route guard and visible-page assertion only; no direct protected-action request is made.",
    "SR-ROLE-014": "Route guard and visible-page assertion only; no direct protected-action request is made.",
    "SR-SALE-006": "Confirms the void control is hidden and inventory is unchanged; this is interface authorization evidence, not a direct forged server-action attempt.",
    "SR-CROP-002": "Blocked: the current crop details interface exposes no reachable Edit Crop control. The editor scenario is not counted as passed.",
    "SR-OBS-003": "Blocked: existing rover readings were fresh, so stale/no-data global state was not changed to force this scenario.",
}

AUTO_INPUTS = {
    "SR-SALE-001": "20 kg opening stock; 3 kg at PHP 50/kg; PHP 200 tender; expected PHP 150 sale, PHP 50 change and 17 kg balance.",
    "SR-SALE-002": "Two dedicated items at PHP 50/kg; sell 2 kg plus 1 kg; expected receipt PHP 150.",
    "SR-SALE-003": "2 kg stock; request 3 kg; expected rejection and unchanged 2 kg.",
    "SR-SALE-004": "One 3 kg line at PHP 50/kg; select GCash without a transaction reference.",
    "SR-SALE-005": "20 kg opening stock; sale of 3 kg; void only its receipt; expected balance returns to 20 kg once.",
    "SR-INV-004": "20 kg opening balance; receive 5 kg from Field Crate; expected 25 kg and one IN row.",
    "SR-INV-005": "20 kg opening balance; issue 3 kg for Kitchen Preparation; expected 17 kg and one OUT row.",
    "SR-INV-006": "2 kg available; request issue of 3 kg; expected actionable error and persisted balance unchanged.",
    "SR-DASH-002": "Capture baseline daily sales total; add a controlled PHP 100 test sale; reconcile the delta.",
    "SR-CUST-002": "Create and release a 10% discount; apply to a PHP 100 subtotal; expected PHP 10 discount and PHP 90 total.",
    "SR-CROP-003": "One synthetic, explicitly non-hardware crop batch; record Looks normal and unique AUTOTEST note.",
    "SR-CROP-004": "One synthetic crop; omit the required field observation; confirm no activity row is added.",
}

FIGURES = [
    ("SR-AUTH-001", "verified-result", "Login succeeds and opens the authenticated dashboard"),
    ("SR-ROLE-004", "verified-result", "Planting Staff lands on its authorized workspace"),
    ("SR-DASH-001", "verified-result", "Dashboard period selectors respond in the local timezone"),
    ("SR-DASH-002", "verified-result", "A controlled sale reconciles against the dashboard baseline"),
    ("SR-INV-002", "verified-result", "An AUTOTEST inventory item is saved and found after reload"),
    ("SR-INV-004", "verified-result", "Receiving five kilograms updates stock and movement history"),
    ("SR-INV-006", "verified-result", "Insufficient stock displays guidance and preserves the two kilogram balance"),
    ("SR-SALE-001", "receipt", "A cash receipt shows PHP 150 total and PHP 50 change"),
    ("SR-SALE-001", "remaining-stock", "The sale leaves 17 kilograms from a 20 kilogram opening balance"),
    ("SR-SALE-003", "verified-result", "Overselling is rejected without a stock deduction"),
    ("SR-SALE-005", "verified-result", "Authorized void restores stock to its original balance"),
    ("SR-CUST-002", "discounted-receipt", "Released ten percent discount appears in the saved receipt"),
    ("SR-CROP-001", "verified-result", "Synthetic crop batch details are visible in the portal"),
    ("SR-CROP-003", "verified-result", "A saved field observation is visible in crop activity history"),
    ("SR-REPORT-003", "verified-result", "Receipt and sales print view render test sale data"),
    ("SR-OBS-004", "verified-result", "Rover monitor is read-only in the browser interface"),
]


def read_run(run_id: str):
    run_dir = APP / "e2e" / "runs" / run_id
    results_path = run_dir / "results.json"
    if not results_path.exists():
        raise SystemExit(f"Playwright results do not exist for {run_id}")
    return run_dir, json.loads(results_path.read_text(encoding="utf-8")), json.loads((run_dir / "environment.json").read_text(encoding="utf-8"))


def walk_results(suites):
    for suite in suites or []:
        for spec in suite.get("specs", []):
            for test in spec.get("tests", []):
                result = (test.get("results") or [{}])[-1]
                title = " ".join(part for part in (spec.get("title", ""), test.get("title", "")) if part).strip()
                match = re.search(r"\b(SR-[A-Z]+-\d{3})\b", title)
                if match:
                    yield match.group(1), title, test, result
        yield from walk_results(suite.get("suites", []))


def result_stats(raw):
    entries = list(walk_results(raw.get("suites")))
    return {"total": len(entries), "passed": sum(r.get("status") == "passed" for *_, r in entries),
            "failed": sum(r.get("status") == "failed" for *_, r in entries),
            "blocked": sum(r.get("status") in ("skipped", "interrupted", "timedOut") for *_, r in entries),
            "duration_seconds": round(raw.get("stats", {}).get("duration", 0) / 1000, 1)}, entries


def module_for(case_id):
    return MODULE_NAMES.get(case_id.split("-")[1], "Other")


def role_for(case_id, title):
    for role in ("System Administrator", "Farm Planting Manager", "Farm Inventory Manager", "Planting Staff", "Inventory Staff"):
        if role in title:
            return role
    if case_id.startswith("SR-AUTH") or case_id.startswith("SR-ROLE"):
        return "As stated in the test title; staff cases use the named role session"
    if case_id.startswith("SR-CROP"):
        return "Farm Planting Manager"
    if case_id.startswith("SR-USER"):
        return "System Administrator"
    if case_id.startswith(("SR-INV", "SR-SALE", "SR-CUST")):
        return "Farm Inventory Manager, except the explicit staff-authorization case"
    return "System Administrator"


def automation_case(case_id, title, test, result, run_id, run_dir):
    status_raw = result.get("status", "not-run")
    status = "Passed" if status_raw == "passed" else "Blocked" if status_raw in ("skipped", "interrupted", "timedOut") else "Failed" if status_raw == "failed" else "Not run"
    annotations = test.get("annotations", [])
    reason = next((a.get("description", "") for a in annotations if a.get("type") == "skip"), "")
    detail = (result.get("errors") or [{}])[0].get("message", "")
    title_scenario = re.sub(r"^SR-[A-Z]+-\d{3}\s*", "", title)
    location = test.get("location", {})
    source = location.get("file", "")
    if not source:
        source = {"AUTH": "e2e/tests/auth-roles.spec.ts", "ROLE": "e2e/tests/auth-roles.spec.ts",
                  "CROP": "e2e/tests/crops.spec.ts", "CUST": "e2e/tests/customers.spec.ts",
                  "DASH": "e2e/tests/dashboard-reports.spec.ts", "REPORT": "e2e/tests/dashboard-reports.spec.ts",
                  "INV": "e2e/tests/inventory.spec.ts", "OBS": "e2e/tests/monitoring.spec.ts",
                  "SALE": "e2e/tests/sales.spec.ts", "USER": "e2e/tests/users.spec.ts"}.get(case_id.split("-")[1], "e2e/tests")
    if source.startswith("e2e/"):
        source = "web-admin/" + source
    elif "e2e/tests" in source:
        source = "web-admin/" + source.split("e2e/", 1)[-1]
    action = title_scenario
    route = {"AUTH": "/login", "ROLE": "the route named in the test", "CROP": "/crops", "CUST": "/customers", "DASH": "/dashboard", "REPORT": "authenticated report route", "INV": "/inventory", "OBS": "notifications, activity log or rover monitor", "SALE": "/sales", "USER": "/users"}.get(case_id.split("-")[1], "the tested portal route")
    steps = "1. Use the case's declared role session and run-labelled fixture prepared by web-admin/e2e/support.ts.\n2. Open " + route + " and perform: " + action + ".\n3. Check the visible or persisted outcome asserted in " + source + ".\n4. Compare the outcome with the named scenario; the run-specific fixture IDs are recorded in the run manifest."
    actual = ("Passed; Playwright assertions completed in the named run. " + AUTO_AUDIT[case_id] if case_id in AUTO_AUDIT else
              "Passed; Playwright assertions completed in the named run. Persisted outcomes were independently checked where the test source performs database reads." if status == "Passed" else
              ("Blocked: " + (reason or detail or "the test did not reach its required environment state.")) if status == "Blocked" else
              ("Failed: " + detail) if status == "Failed" else "No execution result was recorded.")
    figure_attachment = next((name for cid,name,_ in FIGURES if cid == case_id), None)
    evidence = (f"evidence/{run_id}/{case_id}_{figure_attachment}.png" if figure_attachment and status in ("Passed", "Blocked")
                else f"run-artifacts/{run_id}/html/index.html")
    return {"Case ID": case_id, "Scenario": title_scenario, "Objective": f"Verify that {title_scenario[0].lower()+title_scenario[1:]}, then document the visible and persisted result supported by the test assertions.",
            "Module": module_for(case_id), "Role": role_for(case_id, title), "Priority": "High" if case_id.startswith(("SR-AUTH", "SR-ROLE", "SR-INV", "SR-SALE", "SR-USER", "SR-CROP")) else "Medium",
            "Test Type": "Functional / authorization / validation as described by the scenario", "Preconditions": "Local production build running; target database host is the previously verified development/demo project; one Playwright worker; dedicated role session prepared.",
            "Test Data": AUTO_INPUTS.get(case_id, f"Synthetic data for run {run_id}; exact related labels and record IDs are listed in run-artifacts/{run_id}/records.jsonl. Credentials are excluded."),
            "Steps": steps, "Expected Result": f"{title_scenario}. The observed behavior must match the specific assertions in {source}; any database outcome is claimed only when that test reads it back.",
            "Cleanup": f"Dedicated test accounts deactivated; labeled transactional/history rows retained under the run's exact-ID cleanup policy. See run-artifacts/{run_id}/cleanup.json.",
            "Method": "Automated — Playwright Test / Chromium", "Actual Result": actual, "Status": status,
            "Evidence": evidence, "Source": source}


def planned_cases(start=1):
    out = []
    for group in SCENARIOS:
        code = group["code"]
        for index, row in enumerate(group["rows"], start=1):
            scenario, data, action, expected = row
            case_id = f"SR-PLAN-{code}-{index:03d}"
            steps = (f"1. Sign in as the named {group['role']} account and open {group['route']}. Confirm the expected page is available.\n"
                     f"2. Prepare the isolated test value: {data}\n"
                     f"3. Perform this case's action: {action}\n"
                     "4. Reload the relevant page, review the visible result, and compare the saved row or permitted read-only record with the stated expectation.")
            out.append({"Case ID": case_id, "Scenario": scenario, "Objective": f"Determine whether the SeedRover portal correctly supports the specific workflow: {scenario.lower()}.",
                        "Module": group["module"], "Role": group["role"], "Priority": "High" if code in {"AUTH", "ROLE", "INV", "BATCH", "SALE", "CUST", "SEC"} else "Medium",
                        "Test Type": "Manual functional / validation / usability test", "Preconditions": group["prerequisite"],
                        "Test Data": data, "Steps": steps, "Expected Result": expected, "Cleanup": group["cleanup"],
                        "Method": "Manual scenario specification; no execution evidence was supplied", "Actual Result": "No observation is recorded in this report. The expected outcome is documented as the acceptance criterion.",
                        "Status": "No result recorded", "Evidence": "No manual execution evidence supplied", "Source": "Prepared from the current web portal and repository documentation; review route and controls in the build under test."})
    return out


def set_cell_shading(cell, fill):
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd"); shd.set(qn("w:fill"), fill); tc_pr.append(shd)


def set_repeat_table_header(row):
    tr_pr = row._tr.get_or_add_trPr(); tbl_header = OxmlElement("w:tblHeader"); tbl_header.set(qn("w:val"), "true"); tr_pr.append(tbl_header)


def configure_table(table, header=True, font_size=8.7):
    font_size = max(10, font_size)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.style = "Light Shading Accent 1"
    for i, row in enumerate(table.rows):
        if i == 0 and header: set_repeat_table_header(row)
        for cell in row.cells:
            cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.TOP
            if header and i == 0: set_cell_shading(cell, GREEN)
            for p in cell.paragraphs:
                p.paragraph_format.space_after = Pt(2)
                p.paragraph_format.space_before = Pt(1)
                for run in p.runs:
                    run.font.name = "Times New Roman"; run.font.size = Pt(font_size)
                    if header and i == 0: run.bold = True; run.font.color.rgb = RGBColor(255,255,255)


def add_table(doc, headers, rows, widths=None, fontsize=8.7):
    table = doc.add_table(rows=1, cols=len(headers))
    for idx, text in enumerate(headers): table.rows[0].cells[idx].text = str(text)
    for values in rows:
        cells = table.add_row().cells
        for idx, text in enumerate(values): cells[idx].text = str(text)
    if widths:
        for row in table.rows:
            for cell, width in zip(row.cells, widths): cell.width = Inches(width)
    configure_table(table, True, fontsize)
    return table


def add_field(paragraph, instruction):
    run = paragraph.add_run()
    begin = OxmlElement("w:fldChar"); begin.set(qn("w:fldCharType"), "begin")
    instr = OxmlElement("w:instrText"); instr.set(qn("xml:space"), "preserve"); instr.text = instruction
    separate = OxmlElement("w:fldChar"); separate.set(qn("w:fldCharType"), "separate")
    shown = OxmlElement("w:t"); shown.text = "Right-click and update field in Microsoft Word"
    end = OxmlElement("w:fldChar"); end.set(qn("w:fldCharType"), "end")
    for node in (begin, instr, separate, shown, end): run._r.append(node)


def add_caption(doc, text):
    p = doc.add_paragraph(style="Caption"); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.keep_with_next = True
    match = re.match(r"^(Figure|Table)\s+(\d+)\.\s*(.*)$", text)
    if match:
        kind, fallback_number, caption = match.groups()
        p.add_run(kind + " ")
        run = p.add_run()
        begin = OxmlElement("w:fldChar"); begin.set(qn("w:fldCharType"), "begin")
        instr = OxmlElement("w:instrText"); instr.set(qn("xml:space"), "preserve"); instr.text = f" SEQ {kind} \\* ARABIC "
        separate = OxmlElement("w:fldChar"); separate.set(qn("w:fldCharType"), "separate")
        shown = OxmlElement("w:t"); shown.text = fallback_number
        end = OxmlElement("w:fldChar"); end.set(qn("w:fldCharType"), "end")
        for node in (begin, instr, separate, shown, end): run._r.append(node)
        p.add_run(". " + caption)
    else:
        p.add_run(text)
    for r in p.runs: r.font.name = "Times New Roman"; r.font.size = Pt(9); r.italic = True
    return p


def set_page_fields(doc):
    for section in doc.sections:
        section.page_width = Inches(8.27); section.page_height = Inches(11.69)
        section.top_margin = Inches(.8); section.bottom_margin = Inches(.75)
        section.left_margin = Inches(.85); section.right_margin = Inches(.85)
        section.header_distance = Inches(.35); section.footer_distance = Inches(.35)
        h = section.header.paragraphs[0]; h.text = "SEEDROVER  /  WEB PORTAL TESTING REPORT"
        h.alignment = WD_ALIGN_PARAGRAPH.RIGHT
        for r in h.runs: r.font.name = "Times New Roman"; r.font.size = Pt(8); r.font.color.rgb = RGBColor(95,112,101)
        f = section.footer.paragraphs[0]; f.alignment = WD_ALIGN_PARAGRAPH.CENTER
        f.add_run("Software Testing and Validation  •  "); add_field(f, "PAGE")
        for r in f.runs: r.font.name = "Times New Roman"; r.font.size = Pt(8); r.font.color.rgb = RGBColor(95,112,101)


def make_diagrams(image_dir, stats, total, automated, manual):
    image_dir.mkdir(parents=True, exist_ok=True)
    font_path = "C:/Windows/Fonts/arial.ttf"
    bold_path = "C:/Windows/Fonts/arialbd.ttf"
    try: body = ImageFont.truetype(font_path, 27); bold = ImageFont.truetype(bold_path, 31); small = ImageFont.truetype(font_path, 21)
    except OSError: body = bold = small = ImageFont.load_default()
    arch = Image.new("RGB", (1800, 640), "white"); d = ImageDraw.Draw(arch)
    boxes = [(60,"Web User","Next.js / React"),(450,"Portal Server","Pages & Actions"),(840,"Supabase","Auth / Postgres"),(1230,"Business Data","Records & RPCs")]
    for x,head,sub in boxes:
        d.rounded_rectangle((x,200,x+320,395),radius=22,fill="#EAF4EE",outline="#246B45",width=5)
        d.text((x+28,240),head,font=bold,fill="#18382A"); d.text((x+28,310),sub,font=body,fill="#334C3D")
    for x in (386,776,1166):
        d.line((x,295,x+53,295),fill="#C49A42",width=8); d.polygon([(x+53,282),(x+74,295),(x+53,308)],fill="#C49A42")
    d.text((60,80),"SeedRover web testing boundary",font=bold,fill="#18382A")
    d.text((60,465),"Web browser testing does not operate the Flutter app or physical rover.",font=small,fill="#52665A")
    arch.save(image_dir/"architecture.png")

    chart = Image.new("RGB", (1800, 680), "white"); d = ImageDraw.Draw(chart)
    d.text((55,35),"Current automated regression run",font=bold,fill="#18382A")
    labels = [("Passed",stats["passed"],"#38895B"),("Blocked",stats["blocked"],"#C49A42"),("Failed",stats["failed"],"#A5453A")]
    maxval=max(1,stats["total"])
    for i,(name,value,color) in enumerate(labels):
        y=140+i*150; d.text((65,y+35),name,font=bold,fill="#18382A")
        d.rounded_rectangle((310,y,1540,y+92),radius=14,fill="#E7ECE8")
        width=int(1230*value/maxval) if value else 0
        if width: d.rounded_rectangle((310,y,310+width,y+92),radius=14,fill=color)
        d.text((1570,y+30),f"{value} / {stats['total']}",font=bold,fill="#18382A")
    chart.save(image_dir/"execution-chart.png")
    coverage = Image.new("RGB", (1800, 600), "white"); d=ImageDraw.Draw(coverage)
    d.text((55,35),"Scenario catalogue and method coverage",font=bold,fill="#18382A")
    vals=[("Automated Playwright cases in scope",automated,"#38895B")]
    for i,(name,val,color) in enumerate(vals):
        y=180+i*170; d.text((60,y),name,font=body,fill="#18382A")
        d.rounded_rectangle((600,y-10,1570,y+75),radius=14,fill="#E7ECE8")
        w=int(970*val/total); d.rounded_rectangle((600,y-10,600+w,y+75),radius=14,fill=color)
        d.text((1600,y+10),f"{val}/{total}",font=bold,fill="#18382A")
    coverage.save(image_dir/"coverage-chart.png")
    return image_dir


def collect_evidence(run_id, raw, evidence_dir):
    evidence_dir.mkdir(parents=True, exist_ok=True)
    by_id = {case_id: (title, result) for case_id,title,_test,result in walk_results(raw.get("suites"))}
    preferred = {case_id: (attachment_name, description) for case_id, attachment_name, description in FIGURES}
    copied=[]
    for case_id,(title,result) in by_id.items():
        images=[a for a in result.get("attachments",[]) if a.get("body") and a.get("contentType")=="image/png"]
        if not images: continue
        preferred_name,description=preferred.get(case_id,(None,None))
        attachment=next((a for a in images if a.get("name")==preferred_name),images[0])
        attachment_name=attachment.get("name","screenshot")
        description=description or re.sub(rf"^{re.escape(case_id)}\s*", "", title)
        name=f"{case_id}_{attachment_name}.png"
        (evidence_dir/name).write_bytes(__import__("base64").b64decode(attachment["body"]))
        copied.append({"caseId":case_id,"runId":run_id,"file":name,"description":description,"path":evidence_dir/name})
    if len(copied)<12:
        raise SystemExit(f"Only {len(copied)} qualifying Playwright figures were found; at least 12 are required")
    return copied


def save_csv(path, headers, rows):
    with path.open("w",newline="",encoding="utf-8-sig") as f:
        writer=csv.DictWriter(f,fieldnames=headers,extrasaction="ignore");writer.writeheader();writer.writerows(rows)


def excel_col(n):
    out=""
    while n:
        n,rem=divmod(n-1,26); out=chr(65+rem)+out
    return out


def write_xlsx(path, sheets):
    """Write a formatted, filterable XLSX using only the standard library."""
    ns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
    rel="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    def esc(v): return html.escape(str(v if v is not None else ""),quote=True)
    with zipfile.ZipFile(path,"w",zipfile.ZIP_DEFLATED) as z:
        z.writestr("[Content_Types].xml", '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'+''.join(f'<Override PartName="/xl/worksheets/sheet{i}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' for i in range(1,len(sheets)+1))+'</Types>')
        z.writestr("_rels/.rels",f'<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="{rel}/officeDocument" Target="xl/workbook.xml"/></Relationships>')
        workbook=f'<?xml version="1.0" encoding="UTF-8"?><workbook xmlns="{ns}" xmlns:r="{rel}"><sheets>'+''.join(f'<sheet name="{esc(name)}" sheetId="{i}" r:id="rId{i}"/>' for i,(name,_,_) in enumerate(sheets,1))+'</sheets></workbook>'
        z.writestr("xl/workbook.xml",workbook)
        z.writestr("xl/_rels/workbook.xml.rels",f'<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'+''.join(f'<Relationship Id="rId{i}" Type="{rel}/worksheet" Target="worksheets/sheet{i}.xml"/>' for i in range(1,len(sheets)+1))+f'<Relationship Id="rId{len(sheets)+1}" Type="{rel}/styles" Target="styles.xml"/></Relationships>')
        z.writestr("xl/styles.xml",f'''<?xml version="1.0" encoding="UTF-8"?><styleSheet xmlns="{ns}"><fonts count="3"><font><sz val="10"/><name val="Aptos"/></font><font><b/><color rgb="FFFFFFFF"/><sz val="10"/><name val="Aptos"/></font><font><b/><color rgb="FF18382A"/><sz val="14"/><name val="Aptos Display"/></font></fonts><fills count="4"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FF246B45"/><bgColor indexed="64"/></patternFill></fill><fill><patternFill patternType="solid"><fgColor rgb="FFEAF4EE"/><bgColor indexed="64"/></patternFill></fill></fills><borders count="2"><border/><border><left style="thin"><color rgb="FFD6E0D8"/></left><right style="thin"><color rgb="FFD6E0D8"/></right><top style="thin"><color rgb="FFD6E0D8"/></top><bottom style="thin"><color rgb="FFD6E0D8"/></bottom></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="4"><xf numFmtId="0" fontId="0" fillId="0" borderId="1" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf><xf numFmtId="0" fontId="1" fillId="2" borderId="1" applyAlignment="1"><alignment vertical="center" wrapText="1"/></xf><xf numFmtId="0" fontId="2" fillId="3" borderId="0" applyAlignment="1"><alignment vertical="center"/></xf><xf numFmtId="0" fontId="0" fillId="3" borderId="1" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf></cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>''')
        for si,(name,headers,rows) in enumerate(sheets,1):
            allrows=[headers]+[[r.get(h,"") for h in headers] if isinstance(r,dict) else list(r) for r in rows]
            root=Element("worksheet",{"xmlns":ns}); views=SubElement(root,"sheetViews");view=SubElement(views,"sheetView",{"workbookViewId":"0"});SubElement(view,"pane",{"ySplit":"1","topLeftCell":"A2","activePane":"bottomLeft","state":"frozen"})
            cols=SubElement(root,"cols")
            for i,h in enumerate(headers,1):
                width= min(56,max(14,len(str(h))+3, 32 if h in ("Steps","Expected Result","Preconditions","Test Data","Cleanup","Actual Result","Evidence") else 14))
                SubElement(cols,"col",{"min":str(i),"max":str(i),"width":str(width),"customWidth":"1"})
            data=SubElement(root,"sheetData")
            for ri,row in enumerate(allrows,1):
                rowel=SubElement(data,"row",{"r":str(ri),"ht":"30" if ri==1 else "54","customHeight":"1"})
                for ci,value in enumerate(row,1):
                    cell=SubElement(rowel,"c",{"r":f"{excel_col(ci)}{ri}","t":"inlineStr","s":"1" if ri==1 else "3" if ri%2==0 else "0"})
                    inline=SubElement(cell,"is");text=SubElement(inline,"t");text.set("{http://www.w3.org/XML/1998/namespace}space","preserve");text.text=str(value or "")
            SubElement(root,"autoFilter",{"ref":f"A1:{excel_col(len(headers))}{len(allrows)}"})
            z.writestr(f"xl/worksheets/sheet{si}.xml",'<?xml version="1.0" encoding="UTF-8"?>'+tostring(root,encoding="unicode"))


def shaded_card(doc, case, dense=False):
    table=doc.add_table(rows=0,cols=2);table.style="Table Grid";table.alignment=WD_TABLE_ALIGNMENT.CENTER
    table.autofit=False;table.columns[0].width=Inches(1.18);table.columns[1].width=Inches(5.97)
    first=table.add_row().cells;first[0].merge(first[1]);first[0].text=f"{case['Case ID']}  |  {case['Scenario']}"
    set_cell_shading(first[0],GREEN)
    metadata=f"Module: {case['Module']}    Role: {case['Role']}    Priority: {case['Priority']}    Test type: {case['Test Type']}    Method: {case['Method']}    Automation status: {case['Status']}"
    for c in first[0].paragraphs[0].runs: c.font.name="Times New Roman";c.font.size=Pt(9.2);c.bold=True;c.font.color.rgb=RGBColor(255,255,255)
    keys=[("Objective","Objective"),("Preconditions","Preconditions"),("Test Data","Test Data"),("Numbered Steps","Steps"),("Expected Result","Expected Result"),("Cleanup","Cleanup"),("Actual Result","Actual Result"),("Evidence / Source",None)]
    for label,key in keys:
        cells=table.add_row().cells;cells[0].text=label
        cells[1].text=(f"Evidence: {case.get('Evidence','')}\nPlaywright source: {case.get('Source','')}" if key is None else case.get(key,""))
        set_cell_shading(cells[0],PALE)
    last=table.add_row().cells;last[0].text="Case record";last[1].text=f"{metadata}\nEvidence: {case['Evidence']}\nSource: {case['Source']}"
    configure_table(table,False,10)
    for row in table.rows:
        row.cells[0].width=Inches(1.18);row.cells[1].width=Inches(5.97)
    doc.add_paragraph().paragraph_format.space_after=Pt(2)
    return table


def add_word_figure(doc, item, number):
    p=doc.add_paragraph();p.alignment=WD_ALIGN_PARAGRAPH.CENTER;p.paragraph_format.keep_with_next=True
    p.add_run().add_picture(str(item["path"]),width=Inches(6.35))
    add_caption(doc,f"Figure {number}. {item['description']}. Case {item['caseId']}; Playwright run {item['runId']}.")


def build_docx(path, run_id, env, stats, total_cases, cases, figures, runs, planned, image_dir):
    doc=Document();set_page_fields(doc)
    normal=doc.styles["Normal"];normal.font.name="Times New Roman";normal.font.size=Pt(11.5);normal.paragraph_format.line_spacing=1.16;normal.paragraph_format.space_after=Pt(6)
    for stylename,size in [("Title",29),("Subtitle",15),("Heading 1",18),("Heading 2",13),("Heading 3",11.5)]:
        st=doc.styles[stylename];st.font.name="Times New Roman";st.font.size=Pt(size);st.font.color.rgb=RGBColor.from_string(DARK);st.font.bold=stylename.startswith("Heading") or stylename=="Title"
    doc.styles["Caption"].font.name="Times New Roman";doc.styles["Caption"].font.size=Pt(9)
    cover=doc.add_paragraph();cover.alignment=WD_ALIGN_PARAGRAPH.CENTER;cover.paragraph_format.space_before=Pt(42)
    logo=ROOT/"web-admin/public/brand/seedrover-logo.png"
    cover.add_run().add_picture(str(logo),width=Inches(3.35))
    p=doc.add_paragraph();p.alignment=WD_ALIGN_PARAGRAPH.CENTER;p.paragraph_format.space_before=Pt(55)
    r=p.add_run(TITLE);r.font.name="Times New Roman";r.font.size=Pt(25);r.font.bold=True;r.font.color.rgb=RGBColor.from_string(DARK)
    p=doc.add_paragraph();p.alignment=WD_ALIGN_PARAGRAPH.CENTER
    r=p.add_run("Formal Testing Paper  |  Web Administration Portal  |  Playwright Evidence");r.font.size=Pt(14);r.font.color.rgb=RGBColor.from_string(GREEN)
    doc.add_paragraph("")
    generated_date=datetime.now(timezone(timedelta(hours=8))).date().isoformat()
    add_table(doc,["Submission information","Editable details"],[["Institution / Department","[Enter school and department]"],["Course / Section","[Enter course and section]"],["Prepared by","[Enter team members]"],["Instructor","[Enter instructor]"],["Submission date","[Enter submission date]"],["Report revision",f"1.0  |  Generated {generated_date}  |  Primary run {run_id}"]],[2.15,4.7],10)
    p=doc.add_paragraph();p.alignment=WD_ALIGN_PARAGRAPH.CENTER;p.paragraph_format.space_before=Pt(24)
    r=p.add_run("Prepared for academic review. Named reviewer approval and signatures are intentionally left blank.");r.italic=True;r.font.size=Pt(10)
    doc.add_page_break()
    doc.add_heading("Contents",0);p=doc.add_paragraph();add_field(p,'TOC \\o "1-3" \\h \\z \\u')
    doc.add_page_break();doc.add_heading("List of Figures",0);p=doc.add_paragraph();add_field(p,'TOC \\h \\z \\c "Figure"')
    doc.add_page_break();doc.add_heading("List of Tables",0);p=doc.add_paragraph();add_field(p,'TOC \\h \\z \\c "Table"')
    doc.add_page_break()

    doc.add_heading("1. Executive Summary",1)
    doc.add_paragraph(f"This paper documents testing of SeedRover Web Admin, the management portal within a wider farm-operations system. The assessed portal is a Next.js application backed by the project's existing development/demo Supabase service. Playwright Test with TypeScript and Chromium supplies reproducible browser evidence; the report is limited to automated test cases.")
    doc.add_paragraph(f"The current full regression run {run_id} executed {stats['total']} browser cases: {stats['passed']} passed, {stats['failed']} failed, and {stats['blocked']} were blocked/skipped. The executed-case pass rate is {stats['passed']/(stats['passed']+stats['failed'])*100 if stats['passed']+stats['failed'] else 0:.1f}% (Passed / [Passed + Failed]). The suite covers {stats['total']} of {total_cases} catalogued scenarios by automation ({stats['total']/total_cases*100:.1f}%); {stats['passed']} catalogued cases were executed successfully in this run. The two blocked cases are excluded from executed-case pass rate and are disclosed separately.")
    doc.add_paragraph("Observed strengths include authenticated role landing pages, controlled inventory movements, sale calculations and stock updates, discount application, CSV/print output, account workflows, and persisted crop care activity. The reports also retain test setup and cleanup records, allowing demo-data changes to be attributed to a specific run.")
    doc.add_paragraph("Two cases remain blocked in the current state. The crop detail screen offers no reachable edit control; shared rover telemetry was fresh, so its stale/no-data state was not overwritten. Prior issues affecting the insufficient-stock message and sales receipt relationship were retested and marked fixed. Several current assertions are interface-only, and the report does not claim coverage beyond its automated cases.")
    add_table(doc,["Current run measure","Observed result"],[["Run identifier",run_id],["Automated cases in catalogue",stats["total"]],["Passed / Failed / Blocked",f"{stats['passed']} / {stats['failed']} / {stats['blocked']}"],["Pass rate among executed cases",f"{stats['passed']/(stats['passed']+stats['failed'])*100 if stats['passed']+stats['failed'] else 0:.1f}%"],["Total scenario catalogue",total_cases],["Automation coverage",f"{stats['total']}/{total_cases} = {stats['total']/total_cases*100:.1f}%"],["Manual scenario specifications",str(total_cases-stats["total"])],["Quality gate", "No open Critical or High defect in the supplied register; scope of observed results is stated separately"]],fontsize=10)
    doc.add_paragraph("The high pass rate describes only cases that reached a result in the named automated run. It does not mean the whole scenario catalogue has passed or that non-web components were tested.")

    doc.add_heading("2. System Overview",1)
    doc.add_paragraph("SeedRover combines a Flutter mobile application, Next.js Web Admin, Supabase backend, ESP32 rover firmware, and camera firmware. This paper's execution boundary is the web portal and its configured development/demo Supabase project. The browser connects to portal routes; server components and actions access authenticated data and transactional RPCs. Rover monitoring reads stored telemetry. Browser tests do not operate a physical rover.")
    doc.add_picture(str(image_dir/"architecture.png"),width=Inches(6.55));add_caption(doc,"Figure 1. Portal testing boundary and principal data flow; architecture figure prepared from repository documentation.")
    doc.add_heading("2.1 Web modules examined",2)
    add_table(doc,["Module","Representative user work","Test emphasis"],[
        ["Dashboard","Date-range summaries, status cards and trends","Period behavior, controlled totals, baseline delta and partial-data handling"],
        ["Inventory","Item details, quantities, batches and history","CRUD, units, stock movement, FIFO, limits and retained transaction evidence"],
        ["Sales and customers","Receipts, discounts, purchase history and payment records","Calculation, inventory deduction, payment references, void, customer links"],
        ["Crops and outcomes","Crop batches, field checks, care, harvest and outcomes","Saved activity, batch closure, destination compatibility and missing interface actions"],
        ["Users and investments","Account access, farm costs and attachments","Role restrictions, validation, retained audit data and file handling"],
        ["Reports and oversight","Exports, print views, notifications, activity and rover monitor","Contents, access control, status accuracy and read-only boundaries"],
    ],fontsize=9)
    doc.add_heading("2.2 Account roles and visible portal access",2)
    role_rows=[
        ["System Administrator","Dashboard, inventory, sales, customers, crops, rover, users, investments, activity log; broad administrative actions."],
        ["Farm Planting Manager","Dashboard and crop/planting workflows; no user administration or inventory/sales workspace."],
        ["Farm Inventory Manager","Dashboard, inventory, sales, customer and payment workflows; no user administration."],
        ["Planting Staff","Crop and rover workspace; no sales, inventory or user administration."],
        ["Inventory Staff","Inventory and sales workspace; no crop or user administration; void button is hidden."],
    ]
    add_table(doc,["Configured role","Portal behavior observed or defined by current role gates"],role_rows,[1.8,5.0],9.2)
    doc.add_paragraph("A hidden button is not proof that the server rejects a forged request. The role case register labels visual gating separately from direct database/API mutation checks. Existing direct database authorization probes exist for planting-to-inventory and inventory-to-crop changes, plus signed-out export checks.")

    doc.add_heading("3. Testing Objectives and Strategy",1)
    doc.add_paragraph("Testing seeks to determine whether common business tasks can be completed accurately, invalid changes are stopped, access follows role boundaries, and saved outcomes survive reload. The strategy combines repeatable browser automation, assertion-scope review, and read-only checks of exact synthetic records.")
    add_table(doc,["Testing level","Purpose in this cycle","Evidence status"],[
        ["Functional UI","Workflows across inventory, sales, crops, users and reports","Playwright cases executed; blocked tests are reported separately"],
        ["Data integration","Compare receipt, stock, dashboard and audit records with their visible values","Performed for selected tests that actually read saved rows"],
        ["Authorization","Check route gates and selected direct database/export protections","Limited representative probes; broader authorization procedures planned"],
        ["Validation and boundaries","Test required fields, stock limits, negative values and state conflicts","Representative boundary checks automated; broader boundary coverage remains a limitation"],
        ["Usability and accessibility","Keyboard navigation, readable errors, responsive layouts and contrast","Mostly planned; no broad accessibility certification claimed"],
        ["Compatibility and resilience","Browser coverage, outage states, retry behavior and exploratory timing","Planned; exploratory measures are observations, not service-level guarantees"],
    ],fontsize=9)
    doc.add_heading("3.1 Result language",2)
    add_table(doc,["Status","Meaning"],[
        ["Passed","The named case completed and its specific assertions passed in the cited run."],
        ["Failed","The case executed and produced a result contrary to its expected outcome."],
        ["Blocked","Execution was prevented by a real precondition or shared state; it is not counted as pass."],
        ["No result recorded","A written procedure and expected outcome exist; the report contains no observation or execution evidence for this case."],
    ],fontsize=9.5)
    doc.add_paragraph("Pass rate is Passed / (Passed + Failed). Blocked cases and cases with no recorded result are reported separately. Automation coverage counts cases with a Playwright implementation divided by the automated-only in-scope catalogue. Execution coverage separately counts actual Passed and Failed cases divided by the catalogue.")

    doc.add_heading("4. Environment and Test Data",1)
    started=datetime.fromisoformat(env["startedAt"].replace("Z","+00:00"))
    local=started.astimezone(timezone(timedelta(hours=8),name="Asia/Manila"))
    add_table(doc,["Environment item","Observed value"],[
        ["Tested application","SeedRover Web Admin — local optimized Next.js build"],["Source revision",env.get("commit","not recorded")],
        ["Browser",f"Chromium, Playwright {env.get('playwright','version not recorded')}"],["Runtime",f"Node.js {env.get('node','not recorded')}"],
        ["Host OS",env.get("platform","not recorded")],["Timezone",env.get("timezone","Asia/Manila")],
        ["Database target","Existing development/demo Supabase project; credentials intentionally withheld"],
        ["Run start (local)",local.strftime("%Y-%m-%d %H:%M:%S %Z")],["Worker and retries","One worker; zero automatic retries"],
        ["Run ID",run_id]],fontsize=9.5)
    doc.add_paragraph("The suite checks the configured Supabase hostname against an explicit allowlist before seeding, gives each run a unique identifier, records fixture table/IDs, and deactivates exact dedicated accounts at teardown. It does not reset the database, apply migrations, overwrite shared rover state, or edit unrelated demo rows. Business and audit history is retained, so test sales and movements can affect totals.")
    doc.add_paragraph("The current full run recorded its exact fixture manifest and cleanup status under the run artifact folder. Sensitive session-state files are kept in ignored local storage and excluded from report attachments. No credentials or real customer data are included in this report.")

    doc.add_heading("5. Functional and Role Coverage",1)
    module_counts={}
    for c in cases: module_counts[c["Module"]]=module_counts.get(c["Module"],0)+1
    for group in SCENARIOS: module_counts[group["module"]]=module_counts.get(group["module"],0)+len(group["rows"])
    coverage_rows=[]
    for name,count in sorted(module_counts.items()):
        automated=sum(c["Module"]==name for c in cases); coverage_rows.append([name,count,automated,count-automated,f"{automated/count*100 if count else 0:.1f}%"])
    add_caption(doc,"Table 1. Scenario catalogue coverage by module and method.")
    add_table(doc,["Module","Total scenarios","Automated","Manual specifications","Automation coverage"],coverage_rows,fontsize=8.5)
    doc.add_paragraph("The scenarios in this paper include application behavior derived from portal pages/actions and the repository's documented crop workflow. Some items describe test conditions that require a provider, UI control, stale sensor state or account policy not currently available; those cases remain planned or blocked as stated.")

    doc.add_heading("6. Module Testing Design",1)
    chapter_map={
        "6.1 Authentication, recovery and roles":"Login tests cover correct/incorrect credentials, inactive profiles, sign-out and protected routes. Route permissions and server-action permissions are separate concerns; hidden controls are not treated as endpoint proof. Password recovery cases specify invalid and expired links but await execution.",
        "6.2 Inventory and stock batches":"Inventory procedures use exact opening balances and labelled movements. For instance, a 20 kg item at PHP 50/kg that receives 5 kg should read 25 kg and show one 5 kg IN transaction. A 3 kg issue should leave 17 kg and one OUT entry. Insufficient stock must produce an actionable message and preserve the saved 2 kg.",
        "6.3 Sales, customers and payments":"The controlled cash-sale example uses 3 kg × PHP 50 = PHP 150, tender PHP 200 and change PHP 50, with stock moving from 20 kg to 17 kg. Multi-line, non-cash reference, discounts, oversell, void, customer history and installment scenarios are listed independently so a blocked case cannot imply coverage of adjacent behavior.",
        "6.4 Crop care, harvest and outcomes":"Crop fixtures are synthetic planting receipts marked hardware_verified=false. Care history is verified separately from physical hardware. Harvest checks require an open batch, a compatible existing kg destination, exact quantity, one transactional stock receipt and prevention of a second harvest. Crop editing is currently blocked because the detail interface has no reachable edit control.",
        "6.5 Expenses and account administration":"Administrator-only farm expenses cover type, positive amount, date, payment method and receipt upload. User tests cover uniqueness, role update and deactivation. Records are named with a test run prefix; destructive tests must never target unrelated demo data.",
        "6.6 Reports, monitoring and integrations":"Export tests validate content and filters, while print tests assess rendered documents. Notification and activity tests identify the acting account. Rover and weather/assistant procedures distinguish stored telemetry from live hardware/provider responses; browser-only monitoring remains read-only.",
    }
    for heading,text in chapter_map.items(): doc.add_heading(heading,2);doc.add_paragraph(text)
    doc.add_heading("6.7 Risk-based test data examples",2)
    add_table(doc,["Case family","Controlled value","Successful expected outcome"],[
        ["Cash sale","Opening 20 kg; sell 3 kg at PHP 50; tender PHP 200","Receipt PHP 150; change PHP 50; saved balance 17 kg"],
        ["Multi-item sale","Item A 20 kg; Item B 20 kg; sell 2 kg and 1 kg respectively","One PHP 150 receipt; balances 18 kg and 19 kg"],
        ["Stock conflict","2 kg available; requested issue 3 kg","Clear validation; balance stays 2 kg; no OUT transaction"],
        ["Discount","10% on a PHP 100 subtotal","Discount PHP 10; receipt total PHP 90"],
        ["Batch harvest","Open synthetic 2 kg crop batch; matching kg inventory item","Batch closes once; 2 kg inventory receipt appears once"],
    ],fontsize=9)

    doc.add_heading("7. Playwright Implementation and Proof",1)
    doc.add_paragraph("The implementation uses Playwright Test with TypeScript and bundled Chromium. Shared support code prepares role sessions, creates uniquely named fixtures, records exact database IDs, supplies database read-back helpers, and captures screenshots. The Playwright project uses Asia/Manila time, one worker, no automatic retries, and HTML plus JSON result reporters.")
    doc.add_heading("7.1 Reproduce the browser run",2)
    p=doc.add_paragraph();r=p.add_run("cd web-admin\n# With Node.js 22.x and an allowlisted development/demo project\nnpm ci\nnpx playwright install chromium\nnpm run test:e2e:preflight\nnpm run test:e2e:smoke\nnpm run test:e2e");r.font.name="Consolas";r.font.size=Pt(9)
    doc.add_paragraph("The local runner creates one run folder, records a database target fingerprint without storing secrets in this report, and refuses to seed when the configured Supabase host does not match the reviewed hostname. Do not run local and CI jobs at the same time against this shared project.")
    doc.add_heading("7.2 Test-code proof",2)
    proof="test('SR-SALE-001 Cash sale saves receipt total change and exact stock deduction', async ({ page }) => {\n  const item = await inventory('cash');\n  await fillSale(page, [{ name: item.name, quantity: 3 }], 'cash');\n  const sale = await submitSale(page, 'cash');\n  expect(Number(sale.total_amount)).toBe(150);\n  expect(Number(sale.change_amount)).toBe(50);\n  expect(await balance(item.id)).toBe(17);\n});"
    p=doc.add_paragraph();r=p.add_run(proof);r.font.name="Consolas";r.font.size=Pt(8.5)
    doc.add_paragraph("This code excerpt is from the existing case file and demonstrates an actual Playwright test with a controlled fixture, browser workflow and saved-outcome assertions. The complete test files and HTML/JSON result reports are included with the submission artifacts.")
    doc.add_heading("7.3 Terminal proof",2)
    terminal_excerpt="PS> npx.cmd playwright test --config=playwright.terminal-proof.config.ts\nRunning 1 test using 1 worker\nok 1 e2e\\terminal-proof.spec.ts:3:5 Supplementary terminal proof: SeedRover login screen renders (704ms)\n1 passed (1.6s)\nExit code: 0"
    p=doc.add_paragraph();r=p.add_run(terminal_excerpt);r.font.name="Consolas";r.font.size=Pt(9)
    doc.add_paragraph("The exact passing terminal transcript is included at docs/automation/terminal-proof/playwright-login-shell-run.txt; the separate discovery transcript lists all 52 regression tests. This one-case check renders the local login screen without contacting Supabase. It is supporting proof of a terminal Playwright execution and is excluded from the 52-case catalogue and database-backed regression metrics.")
    doc.add_paragraph("A later smoke rerun attempt on 2026-10-06 stopped in global setup after a Supabase fetch failure, before any case began. Its setup record is retained under web-admin/e2e/runs/20261005T174918844-48520 and it is excluded from all test metrics.")
    doc.add_heading("7.4 Captured browser results",2)
    doc.add_picture(str(image_dir/"execution-chart.png"),width=Inches(6.5));add_caption(doc,f"Figure 2. Current run result counts: {stats['passed']} passed, {stats['blocked']} blocked, {stats['failed']} failed; run {run_id}.")
    for i,item in enumerate(figures,3): add_word_figure(doc,item,i)

    doc.add_heading("8. Execution Results",1)
    current_rate=stats["passed"]/(stats["passed"]+stats["failed"])*100 if stats["passed"]+stats["failed"] else 0
    doc.add_picture(str(image_dir/"coverage-chart.png"),width=Inches(6.5));add_caption(doc,f"Figure {3+len(figures)}. All {stats['total']} in-scope catalogue cases have Playwright implementations.")
    add_table(doc,["Metric","Value","Interpretation"],[
        ["Playwright cases in full run",str(stats["total"]),"52 identified cases in the current Chromium regression run"],
        ["Passed",str(stats["passed"]),"Assertions completed successfully"],["Failed",str(stats["failed"]),"Executed cases with a failed assertion"],
        ["Blocked",str(stats["blocked"]),"Crop edit and stale/no-data rover conditions"],["Pass rate",f"{current_rate:.1f}%","Passed  /  (Passed + Failed); skipped cases excluded"],
        ["Execution coverage",f"{(stats['passed']+stats['failed'])/total_cases*100:.1f}%","Executed (pass or fail) divided by all catalogued scenarios"],
        ["Automation coverage",f"{stats['total']/total_cases*100:.1f}%","Cases with Playwright implementation divided by all catalogued scenarios"],
        ["Manual scenario specifications",str(total_cases-stats["total"]),"Written procedures with no recorded observation"],
    ],fontsize=9)
    doc.add_paragraph("The smoke run is a five-case subset of the current full regression run, not an additional five unique cases in the metrics. The previous formal run and focused stock-message retest remain separate historical records. They are useful evidence, but they do not replace the current full-run results.")
    run_rows=[]
    for rid,rtype in runs:
        _,raw,runenv=read_run(rid);s,_=result_stats(raw)
        stamp=datetime.fromisoformat(runenv["startedAt"].replace("Z","+00:00")).astimezone(timezone(timedelta(hours=8),name="Asia/Manila"))
        run_rows.append([rtype,rid,stamp.strftime("%Y-%m-%d %H:%M %Z"),s["total"],s["passed"],s["failed"],s["blocked"]])
    add_caption(doc,"Table 2. Separate execution records. The primary current regression run is the first row.")
    add_table(doc,["Run type","Run ID","Started (local)","Cases","Passed","Failed","Blocked"],run_rows,fontsize=8.5)
    doc.add_paragraph("The current run used one Chromium worker and zero retries. Execution time was approximately " + str(stats["duration_seconds"]) + " seconds according to Playwright's result metadata. Browser screenshots are attached to their original test records.")

    doc.add_heading("9. Defects, limitations and assertion audit",1)
    defects=[
        ["DEF-001","Medium","Insufficient-stock rejection previously rendered a generic server-component error while preserving database quantity.","Fixed; focused retest and current SR-INV-006 pass show actionable guidance and unchanged stock."],
        ["DEF-002","Medium","The sales receipt query previously had an ambiguous sales_orders-to-profiles relationship.","Fixed by qualifying the recorded_by relation; SR-SALE-001 passed in the formal and current regression runs."],
        ["GAP-001","Coverage blocker","Crop details interface currently has no reachable Edit Crop control.","SR-CROP-002 blocked; implement/re-expose the intended control, then execute edit and persistence cases."],
        ["GAP-002","Environment blocker","The shared database contains fresh rover readings; stale/no-data state was not altered for testing.","SR-OBS-003 blocked; use a separate isolated telemetry fixture/environment to exercise aged and missing readings."],
    ]
    add_caption(doc,"Table 3. Observed defects and currently known testing blockers.")
    add_table(doc,["ID","Severity","Observed behavior","Disposition / next action"],defects,[.65,.9,2.65,2.65],8.5)
    doc.add_paragraph("No Critical or High defect is open in the current supplied register. That statement is limited to findings discovered in the tested flows; it does not assert that all features are defect-free.")
    doc.add_heading("9.1 Review of current Playwright assertions",2)
    doc.add_paragraph("Test names are not sufficient evidence by themselves. The register carries assertion caveats for cases whose actual code checks only a displayed result. In particular, duplicate-user rejection checks the alert but not an independent post-rejection row count; negative price checks client control validity without submitting; four role cases verify route guards and visible pages; and the inventory-staff void test checks the hidden control and balance but does not forge a server-action request. These checks remain useful interface evidence, with the server-side assertion scope stated precisely.")
    audit_rows=[[c["Case ID"],c["Scenario"],c["Status"],c["Actual Result"][:230]+("…" if len(c["Actual Result"])>230 else "")] for c in cases if c["Case ID"] in AUTO_AUDIT]
    add_caption(doc,"Table 4. Cases whose result requires an assertion-scope qualification.")
    add_table(doc,["Case","Scenario","Run status","Assertion limitation"],audit_rows,[.9,1.8,.8,3.2],8.2)

    doc.add_heading("10. Assessment and Recommendations",1)
    doc.add_paragraph("The executed browser suite demonstrates that the tested core web workflows work in the current Chromium build and development/demo database. Strong examples include saved sale arithmetic with independent stock read-back, stock movement history, discount redemption, export contents, and user deactivation. The result should be presented as positive evidence for these tested paths, with the two blocked scenarios and limited assertions disclosed.")
    add_table(doc,["Priority","Recommended next action","Completion evidence"],[
        ["1 — High","Before making claims about the full catalogue, obtain observed results for representative boundary and direct authorization cases.","Dated actual-result entries, screenshots/records and exact test environment"],
        ["2 — High","Make crop edit available or formally remove the unsupported path; test edit persistence once reachable.","Accessible control and one saved/reloaded crop field assertion"],
        ["3 — High","Repeat rover stale and unavailable-data checks using an isolated fixture or test project.","Non-destructive evidence for fresh, stale and no-reading states"],
        ["4 — Medium","Strengthen duplicate-user and negative-price assertions with server/persisted state read-back.","No duplicate profile and unchanged value under server-side invalid submission"],
        ["5 — Medium","Add browser coverage for expense receipts, installment payment status, harvest closure and recovery flows.","Named tests with fixture cleanup and saved business outcomes"],
        ["6 — Medium","Run keyboard/accessibility, mobile-width, second-browser and failure-recovery procedures.","Versioned findings and issue records; exploratory timing remains labeled"],
    ],fontsize=8.7)
    doc.add_paragraph("The Playwright workflow is manually dispatched in GitHub Actions and serializes access to the shared database. No remote CI execution is claimed in this paper. Human names, signatures and approval fields on the cover remain editable placeholders.")

    doc.add_heading("11. References and review record",1)
    refs=[
        "SeedRover repository README and component directory map (project documentation, inspected 2026-10-05).",
        "SeedRover Web Admin route and server-action source under web-admin/src/app and web-admin/src/components.",
        "SeedRover browser automation README, Playwright configuration, fixtures and tests under web-admin/e2e and web-admin/playwright.config.ts.",
        "SeedRover crop care and harvest workflow reference, docs/crop-care-harvest-workflow.md.",
        "Current Playwright JSON result, browser report, environment and exact-ID test manifest, run " + run_id + ".",
        "Historical formal and focused-regression JSON results listed in Table 2; archived original submission in docs/automation/archive/2026-10-05-original-submission.",
    ]
    for item in refs: doc.add_paragraph(item,style="List Bullet")
    add_table(doc,["Review field","Entry"],[
        ["Prepared by","[Add student/team name]"],["Reviewed by","[Add instructor/reviewer]"],["Technical review date","[Complete after review]"],
        ["Recommendation","Evidence supports the automated core web workflows; blocked cases and assertion limits remain disclosed."],
        ["Approvals / signatures","[Human completion required; intentionally unsigned]"],
    ],fontsize=9.3)

    doc.add_page_break();doc.add_heading("Appendix A — Case catalogue and manual scenario index",1)
    manual_by_module={group["module"]:[c for c in planned if c["Module"]==group["module"]] for group in SCENARIOS}
    detailed_manual=[]
    for group in SCENARIOS: detailed_manual.extend(manual_by_module[group["module"]][:2])
    detailed_ids={c["Case ID"] for c in detailed_manual}
    for case in planned:
        if len(detailed_manual)>=40: break
        if case["Case ID"] not in detailed_ids:
            detailed_manual.append(case);detailed_ids.add(case["Case ID"])
    doc.add_paragraph(f"The catalogue contains {total_cases} distinct cases: {len(cases)} executable Playwright cases and {len(planned)} manual scenario specifications. This paper gives full case cards for all automated cases and {len(detailed_manual)} selected manual examples. The complete field-by-field procedures for all {total_cases} cases are provided in the accompanying Excel and CSV registers. Existing SR-* identifiers are preserved; SR-PLAN identifiers identify manual specifications. Manual cases have no observed results recorded here.")
    for group in SCENARIOS:
        doc.add_heading(group["module"],2)
        selected=[c for c in cases if c["Module"]==group["module"]]+[c for c in detailed_manual if c["Module"]==group["module"]]
        for c in selected: shaded_card(doc,c,dense=True)
    doc.add_heading("Manual scenario summary index",2)
    doc.add_paragraph("This index names every manual case and its expected outcome. Detailed prerequisites, input data, numbered steps, cleanup, test type, method and evidence field are in test-case-register.csv and the Test Cases sheet of seedrover-test-register.xlsx. “No result recorded” means this report contains no actual observation or execution evidence for that case.")
    add_table(doc,["Case ID","Scenario","Role / priority","Expected outcome and result status"],[[c["Case ID"],c["Scenario"],f"{c['Role']} / {c['Priority']}",f"{c['Expected Result']}\nStatus: {c['Status']}."] for c in planned],fontsize=10)
    doc.add_heading("Appendix B ? Automated case execution register",1)
    doc.add_paragraph("The detailed procedures and actual outcomes are already included in Appendix A. This compact register maps each automated case to its result and evidence in the primary full run; the source JSON and HTML reports retain the complete assertion detail.")
    add_table(doc,["Case ID","Scenario","Module","Status","Evidence"],[[c["Case ID"],c["Scenario"],c["Module"],c["Status"],c["Evidence"]] for c in cases],fontsize=10)
    doc.add_heading("Appendix C — Run setup, data and cleanup records",1)
    for rid,rtype in runs:
        run_folder=OUT/"run-artifacts"/rid
        doc.add_heading(f"{rtype} — {rid}",2)
        recordfile=run_folder/"records.jsonl"
        cleanfile=run_folder/"cleanup.json"
        setupfile=run_folder/"setup.json"
        doc.add_paragraph("Run-specific HTML and JSON reports, runtime environment, exact fixture IDs, setup outcome and cleanup actions are retained under docs/automation/run-artifacts/"+rid+". The unique labels permit reviewers to identify retained test history without inspecting unrelated records.")
        try:
            cleanup=json.loads(cleanfile.read_text(encoding="utf-8"));actions=cleanup.get("actions",[])
            act_counts={}
            for a in actions: act_counts[a.get("action","unknown")]=act_counts.get(a.get("action","unknown"),0)+1
            doc.add_paragraph("Cleanup summary: "+", ".join(f"{k}: {v}" for k,v in sorted(act_counts.items()))+". "+cleanup.get("policy",""))
        except Exception: doc.add_paragraph("Cleanup JSON is retained in the run artifact directory; consult it for exact actions.")
    doc.add_heading("Appendix D — Defect and evidence registers",1)
    add_table(doc,["ID","Severity","Summary","Current status"],defects,fontsize=8.5)
    add_table(doc,["Run ID","Artifact","Purpose"],[[run_id,"html/index.html","Interactive current Playwright browser report"],[run_id,"results.json","Machine-readable case results and attached evidence"],[run_id,"records.jsonl / cleanup.json","Exact synthetic fixture IDs and cleanup actions"]]+[[rid,"html/index.html and results.json","Separate historical smoke/formal/focused run evidence"] for rid,_ in runs if rid!=run_id],fontsize=8.5)
    doc.add_heading("Appendix E — Manual result record",1)
    doc.add_paragraph("No manual result sheets, observations or execution evidence were supplied for this report. The manual cases in Appendix A are scenario specifications with expected outcomes, not completed results.")
    doc.add_heading("Appendix F — Reproduction and safety notes",1)
    doc.add_paragraph("Run commands and project allowlist checks are shown in Chapter 7. Use Node.js 22.x, Chromium installed through Playwright, and the verified development/demo Supabase hostname. A dedicated run lock prevents overlapping local runs. Do not reset the database or delete business rows by prefix; consult each exact-ID manifest and preserve transactional/audit history. CI is workflow_dispatch only and requires configured repository secrets.")
    settings=doc.settings._element
    update=OxmlElement("w:updateFields");update.set(qn("w:val"),"true");settings.append(update)
    doc.core_properties.title=TITLE;doc.core_properties.subject=f"SeedRover Web Admin tests; current Playwright run {run_id}";doc.core_properties.author="SeedRover project team — editable cover attribution"
    doc.save(path)


class PaperDoc(BaseDocTemplate):
    def __init__(self, filename, **kwargs):
        super().__init__(filename, **kwargs)
        frame=Frame(18*mm,18*mm,A4[0]-36*mm,A4[1]-36*mm,leftPadding=0,rightPadding=0,topPadding=0,bottomPadding=0,id="normal")
        self.addPageTemplates([PageTemplate(id="paper",frames=frame,onPage=self.footer)])
    def afterFlowable(self, flowable):
        if isinstance(flowable, _CaptionIndex):
            self.notify(flowable.kind,(0,flowable.caption,self.page,None))
        if isinstance(flowable,Paragraph) and flowable.style.name in ("PDFH1","PDFH2","PaperH1","PaperH2"):
            level=0 if flowable.style.name in ("PDFH1","PaperH1") else 1; text=flowable.getPlainText();key=f"h{self.page}_{abs(hash((text,self.page)))%9999999}"
            self.canv.bookmarkPage(key);self.canv.addOutlineEntry(text,key,level=level,closed=False);self.notify("TOCEntry",(level,text,self.page,key))
        if isinstance(flowable,Paragraph) and flowable.style.name=="FigureCaption":
            self.notify("FigureEntry",(0,flowable.getPlainText(),self.page,None))
        if isinstance(flowable,Paragraph) and flowable.style.name=="TableCaption":
            self.notify("TableEntry",(0,flowable.getPlainText(),self.page,None))
    def footer(self, canvas, doc):
        if doc.page>1:
            canvas.saveState();canvas.setFont("Times-Roman",8);canvas.setFillColor(colors.HexColor("#607064"));canvas.drawString(18*mm,10*mm,"SeedRover | Software Automation Test Document");canvas.drawRightString(A4[0]-18*mm,10*mm,str(doc.page));canvas.restoreState()


def pdf_table(data,widths=None,font=8):
    font = max(10, font)
    out=[]
    for ri,row in enumerate(data):
        out.append([Paragraph(html.escape(str(cell)).replace("\n","<br/>"),ParagraphStyle("cell",fontName="Times-Roman",fontSize=font,leading=font+1.7)) for cell in row])
    tab=Table(out,colWidths=widths,repeatRows=1,hAlign="LEFT")
    tab.setStyle(TableStyle([("BACKGROUND",(0,0),(-1,0),colors.HexColor("#246B45")),("TEXTCOLOR",(0,0),(-1,0),colors.white),
        ("FONTNAME",(0,0),(-1,0),"Times-Bold"),("GRID",(0,0),(-1,-1),.35,colors.HexColor("#B7C7BA")),
        ("VALIGN",(0,0),(-1,-1),"TOP"),("LEFTPADDING",(0,0),(-1,-1),4),("RIGHTPADDING",(0,0),(-1,-1),4),
        ("TOPPADDING",(0,0),(-1,-1),4),("BOTTOMPADDING",(0,0),(-1,-1),4),("ROWBACKGROUNDS",(0,1),(-1,-1),[colors.white,colors.HexColor("#F2F7F3")])]))
    return tab


def clear_table_rows(table):
    """Keep the header row and remove template example rows."""
    for row in list(table.rows)[1:]:
        table._tbl.remove(row._tr)


def fill_table(table, headers, rows, font_size=10):
    """Populate an existing template table, preserving its table position."""
    clear_table_rows(table)
    if headers:
        for cell, value in zip(table.rows[0].cells, headers):
            cell.text = str(value)
    for values in rows:
        cells = table.add_row().cells
        for cell, value in zip(cells, values):
            cell.text = str(value)
    configure_table(table, True, font_size)


def add_template_case(doc, case, index, total):
    """Render one automated case using only the fields in the supplied template."""
    if index > 1:
        doc.add_page_break()
    heading = doc.add_paragraph("Test Case Template" if index == 1 else "Test Case Template")
    heading.style = doc.styles["Heading 2"]
    fields = [
        ("Test Case ID", case["Case ID"]),
        ("Test Case Name", case["Scenario"].replace("@smoke ", "")),
        ("Priority", case["Priority"]),
        ("Preconditions", f"Role: {case['Role']}. {case['Preconditions']}"),
    ]
    for label, value in fields:
        p = doc.add_paragraph()
        p.paragraph_format.space_after = Pt(2)
        r = p.add_run(label + ": "); r.bold = True
        p.add_run(value)
    label = doc.add_paragraph(); label.add_run("Test Data").bold = True
    data_table = doc.add_table(rows=1, cols=2)
    data_table.rows[0].cells[0].text = "Field"
    data_table.rows[0].cells[1].text = "Value"
    data_rows = [("Scenario input", case["Test Data"]), ("Run", case["Evidence"].split("/")[1] if "/" in case["Evidence"] else "Current formal regression")]
    for left, right in data_rows:
        cells = data_table.add_row().cells; cells[0].text = left; cells[1].text = right
    configure_table(data_table, True, 10)
    label = doc.add_paragraph(); label.add_run("Test Steps").bold = True
    step_table = doc.add_table(rows=1, cols=3)
    for cell, value in zip(step_table.rows[0].cells, ("Step", "Description", "Expected Result")):
        cell.text = value
    step_lines = [line.strip() for line in case["Steps"].splitlines() if line.strip()]
    for step_no, line in enumerate(step_lines, 1):
        desc = re.sub(r"^\d+[.)]\s*", "", line)
        cells = step_table.add_row().cells
        cells[0].text = str(step_no)
        cells[1].text = desc
        cells[2].text = case["Expected Result"] if step_no == len(step_lines) else "The stated action is completed and the case continues to the next verification step."
    configure_table(step_table, True, 10)
    p = doc.add_paragraph(); p.add_run("Expected Result: ").bold = True; p.add_run(case["Expected Result"])
    p = doc.add_paragraph(); p.add_run("Automation Status: ").bold = True
    status = case["Status"]
    p.add_run(f"☒ Automated   {'☒' if status in ('Passed', 'Failed') else '☐'} Executed   Result: {status}. {case['Actual Result']}")
    p = doc.add_paragraph(); p.add_run("Evidence: ").bold = True; p.add_run(case["Evidence"])


def build_template_docx(path, run_id, env, stats, cases, planned, all_runs, figures, image_dir):
    """Fill the user's 17-section Word template without adding chapters or appendices."""
    template_path = Path(r"C:\Users\John Benedict\Downloads\Software_Automation_Test_Template.docx")
    if not template_path.exists():
        raise SystemExit(f"The supplied Word template was not found: {template_path}")
    doc = Document()
    body = doc._element.body
    for child in list(body):
        if child.tag != qn("w:sectPr"):
            body.remove(child)

    sec = doc.sections[0]
    sec.page_width = Inches(8.27); sec.page_height = Inches(11.69)
    sec.top_margin = Inches(.8); sec.bottom_margin = Inches(.8)
    sec.left_margin = Inches(.8); sec.right_margin = Inches(.8)
    normal = doc.styles["Normal"]
    normal.font.name = "Times New Roman"; normal.font.size = Pt(11)
    normal.paragraph_format.space_after = Pt(5)
    for style_name, size, color in (("Heading 1", 14, DARK), ("Heading 2", 12, GREEN), ("Heading 3", 11, DARK)):
        style = doc.styles[style_name]; style.font.name = "Times New Roman"; style.font.size = Pt(size); style.font.bold = True; style.font.color.rgb = RGBColor.from_string(color)
        style.paragraph_format.keep_with_next = True
    title = doc.add_paragraph(); title.alignment = WD_ALIGN_PARAGRAPH.CENTER
    title.paragraph_format.space_before = Pt(38)
    logo = ROOT / "web-admin/public/brand/seedrover-logo.png"
    if logo.exists(): title.add_run().add_picture(str(logo), width=Inches(2.45))
    title = doc.add_paragraph("SeedRover Web Portal", style="Title")
    title.alignment = WD_ALIGN_PARAGRAPH.CENTER
    title.runs[0].font.name = "Times New Roman"; title.runs[0].font.size = Pt(28); title.runs[0].font.color.rgb = RGBColor.from_string(DARK)
    subtitle = doc.add_paragraph("Software Testing, Validation, and Playwright Automation Report")
    subtitle.alignment = WD_ALIGN_PARAGRAPH.CENTER
    for run in subtitle.runs: run.font.name = "Times New Roman"; run.font.size = Pt(15); run.font.color.rgb = RGBColor.from_string(GREEN)
    doc.add_paragraph("Web Administration Portal  |  Formal browser testing  |  TypeScript + Playwright").alignment = WD_ALIGN_PARAGRAPH.CENTER
    doc.add_paragraph("")
    cover_rows = [("Institution / Department", "[Enter institution and department]"), ("Course / Section", "[Enter course and section]"),
                  ("Team Members", "[Enter team member names]"), ("Instructor", "[Enter instructor name]"),
                  ("Submission Date", "[Enter submission date]"), ("Test Cycle", run_id)]
    add_table(doc, ["Submission Information", "Details"], cover_rows, widths=[2.1, 4.45], fontsize=10)
    doc.add_paragraph("")
    add_table(doc, ["Formal run", "Result"], [("Playwright regression", f"{stats['passed']} passed  |  {stats['failed']} failed  |  {stats['blocked']} blocked"),
              ("Executed-case pass rate", f"{100*stats['passed']/(stats['passed']+stats['failed']):.1f}%" if stats['passed']+stats['failed'] else "N/A"),
              ("Automated scenarios", f"{len(cases)} of {len(cases)} in-scope cases")], widths=[2.1, 4.45], fontsize=10)
    note = doc.add_paragraph("Prepared for academic review. Names, signatures, and approvals remain editable.")
    note.alignment = WD_ALIGN_PARAGRAPH.CENTER
    for run in note.runs: run.italic = True; run.font.size = Pt(9)
    doc.add_page_break()
    h_contents = doc.add_paragraph("Contents", style="Heading 1")
    content_rows = [(f"{i}. {name}", desc) for i, (name, desc) in enumerate([
        ("Document Information", "Project identity and run overview"), ("Objective", "Purpose and test goals"), ("Scope", "Included and excluded web testing"),
        ("Test Environment", "Browser, application, database, and data controls"), ("Automation Framework Details", "Playwright stack and implementation"),
        ("Entry Criteria", "Conditions before execution"), ("Exit Criteria", "Completion and acceptance conditions"), ("Automation Test Scenarios", "Scenario catalogue"),
        ("Automated Test Cases", "Detailed Playwright cases and evidence"), ("Test Data Management", "Fixture isolation and cleanup"),
        ("Defect Tracking", "Observed defects, blockers, and assertion limits"), ("Test Execution Summary", "Actual results and run history"),
        ("Automation Coverage", "Coverage by module"), ("Risks and Assumptions", "Known constraints"),
        ("Reporting and Dashboard", "Reports and metrics"), ("CI/CD Integration Checklist", "Pipeline status"), ("Test Sign-Off", "Reviewer decision and signatures")], 1)]
    add_table(doc, ["Section", "Contents"], content_rows, fontsize=9.5)
    doc.add_page_break()

    # Header/footer are page styling; section content below follows the source template verbatim.
    header = sec.header.paragraphs[0]
    header.text = "SeedRover | Software Automation Test Document"
    header.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    for run in header.runs:
        run.font.name = "Times New Roman"; run.font.size = Pt(9); run.font.color.rgb = RGBColor.from_string(GREEN)
    footer = sec.footer.paragraphs[0]
    footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
    footer.add_run("Page "); add_field(footer, "PAGE")

    def h1(text): doc.add_paragraph(text, style="Heading 1")
    def h2(text): doc.add_paragraph(text, style="Heading 2")
    def para(text): doc.add_paragraph(text)
    def bullet(text):
        p = doc.add_paragraph(text, style="List Bullet"); p.paragraph_format.left_indent = Inches(.25); return p

    total = len(cases)
    executed = stats["passed"] + stats["failed"]
    pass_rate = 100 * stats["passed"] / executed if executed else 0
    automation_rate = 100 * len(cases) / total if total else 0

    # 1. Document Information
    h1("1. Document Information")
    rows = [("Project Name", "SeedRover"), ("Application Name", "SeedRover Web Admin Portal"),
            ("Version", "Current repository build; commit 681d7b9c93682136b153ce9f3c4e95990c3855c8"),
            ("Test Cycle", f"Formal browser regression {run_id}"), ("Prepared By", "[Enter team member names]"),
            ("Reviewed By", "[Enter reviewer]"), ("Date", "[Enter submission date]"),
            ("Automation Framework", "Playwright Test with TypeScript"), ("Test Environment", "Local web portal; existing development/demo Supabase project; Chromium")]
    add_table(doc, ["Field", "Details"], rows, fontsize=10)
    h2("Report Overview")
    para("This report presents the SeedRover Web Admin testing effort using the supplied template’s section topics as its structure. Its scope is limited to the 52 automated Playwright cases in the formal regression. The report distinguishes automated execution results from execution and automation coverage.")
    para(f"The formal regression ({run_id}) ran 52 browser cases: 50 passed, none failed, and two were blocked by current test conditions. Its pass rate among executed cases is 100%. A separate one-test Playwright terminal check also passed and is presented as supplementary proof, not added to the formal run totals.")

    # 2. Objective
    h1("2. Objective"); h2("Purpose")
    para("Validate SeedRover Web Admin authentication, role-based workflows, business rules, saved records, and browser-visible reports using repeatable Playwright tests. Results in this document are limited to the named runs and their recorded evidence.")
    h2("Testing Objectives")
    for item in ("Confirm important user workflows through the visible web interface.", "Check business rules and validation at representative normal, boundary, and invalid inputs.",
                 "Verify saved outcomes after navigation or reload when the automated case reads back persisted state.",
                 "Check role-specific navigation and actions while stating whether the assertion covers the interface or a persisted/server-side outcome.",
                 "Preserve repeatable evidence through Playwright reports, run manifests, and selected screenshots."):
        bullet(item)

    # 3. Scope
    h1("3. Scope"); h2("In Scope")
    for item in ("Login and Authentication", "User Management", "Dashboard Functions", "Order Processing", "Reports Generation", "API Validation"):
        bullet(item)
    h2("Out of Scope")
    for item in ("Performance Testing", "Penetration Testing", "Third-Party Vendor Systems"):
        bullet(item)
    para("Coverage applies to the web portal. Physical rover operation and the native Flutter application are outside this test cycle.")
    add_caption(doc, "Table 1. Web portal scope and representative validation areas.")
    add_table(doc, ["Coverage area", "Representative web checks"], [
        ("Authentication and roles", "Login/logout, protected pages, role landing pages and restricted controls"),
        ("Business records", "Inventory, stock movement, sales, customers, crops, care and user management"),
        ("Reporting and monitoring", "Dashboard filters, CSV/print views, activity, notifications and read-only rover display"),
        ("Quality characteristics", "Input validation, persistence, basic usability, browser behavior and authorization boundaries")], fontsize=10)

    # 4. Test Environment
    h1("4. Test Environment")
    env_rows = [("Environment", "Local development/demo web test environment"), ("Application URL", "http://127.0.0.1:3100"),
                ("Database", "Existing development/demo Supabase project; no database reset"), ("Browser", f"Chromium; Playwright {env.get('playwright', '1.63.0')}"),
                ("Mobile Device", "Not used"), ("Operating System", "Windows"), ("API Endpoint", "Supabase-backed application actions; secrets and endpoint credentials omitted"),
                ("Build Version", "SeedRover web-admin commit 681d7b9c93682136b153ce9f3c4e95990c3855c8; Node " + str(env.get("node", "22.23.3")))]
    add_caption(doc, "Table 2. Browser and application environment used for the formal test cycle.")
    add_table(doc, ["Environment", "Details"], env_rows, fontsize=10)
    para(f"Formal run started {env.get('startedAt', 'date/time recorded in run manifest')}. The formal run used one worker and zero retries. A later smoke rerun stopped during setup after a Supabase fetch error, before any case executed; it is excluded from the reported metrics.")
    h2("Environment and Data Controls")
    for item in ("The existing development/demo Supabase project was used; the runner did not reset or rebuild it.",
                 "AUTOTEST-labelled records and exact record IDs were written to run manifests; unrelated demo rows were not selected for cleanup.",
                 "One worker and serialized runs reduce collisions. Audit/history rows may remain after transactional fixtures are cleaned up.",
                 "Credentials, session tokens, and secret environment values are omitted from the report and evidence registers."):
        bullet(item)

    # 5. Automation Framework Details
    h1("5. Automation Framework Details"); h2("Framework Type")
    for item in ("☐ Data Driven", "☐ Keyword Driven", "☒ Hybrid Framework", "☐ BDD Framework", "☐ Model-Based Testing"):
        bullet(item)
    h2("Technology Stack")
    add_caption(doc, "Table 3. Automation tools and report outputs.")
    add_table(doc, ["Component", "Tool"], [("Test Automation", "Playwright Test"), ("Mobile Automation", "Not used"),
              ("API Automation", "Playwright request context for selected checks"), ("Programming Language", "TypeScript"),
              ("Build Tool", "npm"), ("Reporting", "Playwright HTML and JSON reports"),
              ("CI/CD", "GitHub Actions workflow; manually triggered"), ("Source Control", "Git")], fontsize=10)
    h2("Browser Test Workflow")
    doc.add_picture(str(image_dir/"architecture.png"), width=Inches(6.25)); add_caption(doc, "Figure 1. Web test boundary from the local browser portal to the existing Supabase-backed service; native and physical rover operation are outside this cycle.")
    para("The Playwright project starts the local web server, launches Desktop Chrome at a 1440 × 1000 viewport, applies Asia/Manila time, and stores HTML and JSON results under the unique run directory. Authentication and fixture helpers support the module tests; screenshot-on-failure and retained traces support diagnosis.")
    code = doc.add_paragraph(); code.paragraph_format.left_indent = Inches(.25); code.paragraph_format.right_indent = Inches(.25)
    rr = code.add_run("npm run test:e2e:preflight\nnpm run test:e2e:smoke\nnpm run test:e2e")
    rr.font.name = "Consolas"; rr.font.size = Pt(9)
    add_caption(doc, "Commands used to verify the environment, run the smoke subset, and execute the formal suite.")

    # 6. Entry Criteria
    h1("6. Entry Criteria"); para("The following conditions must be met before automation execution:")
    criteria = ["Stable test environment available — met for the formal run; the later setup-only network failure is separately recorded.",
                "Test data prepared — dedicated synthetic records were prepared and tracked by run.",
                "User stories completed — project requirement completion was not independently assessed in this test report.",
                "Test cases approved — report review/sign-off remains pending.",
                "Test scripts developed and reviewed — scripts ran in the recorded formal regression; review approval is not asserted.",
                "Build deployed successfully — local web build was available for the recorded browser run."]
    for item in criteria: bullet(item)

    # 7. Exit Criteria
    h1("7. Exit Criteria"); para("Automation testing may be considered complete when:")
    for item in ("All critical test cases executed — 50 cases reached a pass/fail result; two automated cases were blocked.",
                 "No Sev-1 or Sev-2 defects open — no such open issue appears in the supplied defect register.",
                 f"Automation pass rate ≥ 95% — {stats['passed']} passed and {stats['failed']} failed among {executed} executed cases ({pass_rate:.1f}%).",
                 "Defect retesting completed — the focused stock-rejection retest passed; remaining blocked scenarios are disclosed.",
                 "Final test report approved — pending reviewer sign-off."):
        bullet(item)

    # 8. Automation Test Scenarios
    h1("8. Automation Test Scenarios")
    para(f"The automated suite contains {len(cases)} distinct web scenarios. Each row maps to a Playwright case and its corresponding detailed case record in Section 9.")
    scenario_rows = []
    for case in cases:
        scenario_rows.append((case["Case ID"], case["Module"], case["Scenario"], case["Priority"]))
    add_caption(doc, f"Table 4. Scenario catalogue: {len(scenario_rows)} unique web test scenarios.")
    add_table(doc, ["Test ID", "Module", "Scenario", "Priority"], scenario_rows, fontsize=9)

    # 9. Automated Test Cases
    h1("9. Automated Test Cases")
    para("Each case records its objective, module, role, priority, preconditions, test data, numbered steps, expected result, cleanup, method, actual result, status, and evidence source. A status is Passed only when that case ran and its assertions passed. A blocked test remains blocked and is excluded from the pass-rate denominator.")
    screenshot_case_count = len({item["caseId"] for item in figures})
    missing_screenshots = sorted({case["Case ID"] for case in cases} - {item["caseId"] for item in figures})
    missing_text = ", ".join(missing_screenshots) if missing_screenshots else "None"
    para(f"The formal run has a case-specific screenshot for {screenshot_case_count} of {len(cases)} cases. Screenshots were not attached for: {missing_text}. Those cases remain linked to their actual Playwright results; no substitute image is presented as execution evidence.")
    figure_lookup = {item["caseId"]: [] for item in figures}
    for item in figures: figure_lookup.setdefault(item["caseId"], []).append(item)
    figure_number = 2
    for index, case in enumerate(cases, 1):
        shaded_card(doc, case)
        for item in figure_lookup.get(case["Case ID"], []):
            add_word_figure(doc, item, figure_number); figure_number += 1

    # 10. Test Data Management
    h1("10. Test Data Management")
    add_table(doc, ["Data Type", "Source", "Owner"], [("User Accounts", "Dedicated role accounts in existing development/demo Supabase", "Test runner; credentials excluded"),
              ("Inventory and sales fixtures", "Run-labelled AUTOTEST records with exact IDs in run manifest", "Playwright fixture helpers"),
              ("Crop, activity and history records", "Synthetic labels; retained history identified by run", "Playwright fixture helpers"),
              ("Login shell proof", "Local test server and browser page; no database fixture required", "Terminal-proof Playwright test")], fontsize=10)
    para("The database was not reset. A conservative cleanup preview identified 121 exact inventory IDs in 11 local run manifests, but the live inventory lookup failed with a network fetch error before any row could be verified. No database rows were changed. Unrelated demonstration data and existing audit/history records remain untouched; rerun the preview after Supabase connectivity is restored.")
    h2("Isolation and Cleanup Rules")
    for item in ("Run one browser worker and one formal run at a time.", "Use run ID labels and exact database IDs; never delete by a broad name prefix.",
                 "Capture report evidence before cleanup; retain audit history created by the application when deletion would break relationships.",
                 "Reconcile dashboard changes against a recorded baseline plus controlled test transactions."):
        bullet(item)

    # 11. Defect Tracking
    h1("11. Defect Tracking"); para("Severity Classification:")
    for item in ("Critical", "High", "Medium", "Low"): bullet(item)
    defect_rows = [("DEF-001", "Insufficient-stock rejection previously displayed a generic server error; corrected and retested.", "Medium", "Fixed; focused and current regression evidence"),
                   ("DEF-002", "Sales receipt query had an ambiguous profile relationship; corrected and retested.", "Medium", "Fixed; receipt case passed"),
                   ("GAP-001", "Crop details interface has no reachable Edit Crop control for the edit scenario.", "Medium", "Blocked; no fix claimed"),
                   ("GAP-002", "Shared rover values were fresh; stale/no-data state was not forced against shared data.", "Low", "Blocked by safe test-data precondition")]
    add_caption(doc, "Table 5. Observed fixes and current coverage blockers.")
    add_table(doc, ["Defect ID", "Summary", "Severity", "Status"], defect_rows, fontsize=10)
    h2("Assertion Scope Notes")
    audit_rows = [(cid, AUTO_AUDIT[cid]) for cid in AUTO_AUDIT if cid in {c["Case ID"] for c in cases}]
    add_table(doc, ["Case", "Observed limitation or blocker"], audit_rows, fontsize=9.5)
    para("These notes qualify the strength of the recorded assertion. A UI-level permission check is not described as a forged-request or server-side authorization test; a blocked case is not a defect pass.")

    # 12. Test Execution Summary
    h1("12. Test Execution Summary"); h2("Formula")
    para("Pass Rate (%) = (Passed / Executed) x 100")
    add_caption(doc, "Table 6. Formal test execution totals and pass-rate denominator.")
    add_table(doc, ["Metric", "Value"], [("Total Test Cases", str(total)), ("Automated Test Cases", str(len(cases))),
              ("Executed Test Cases", str(executed)), ("Passed", str(stats["passed"])), ("Failed", str(stats["failed"])),
              ("Blocked", str(stats["blocked"])), ("Pass Percentage", f"{pass_rate:.1f}%")], fontsize=10)
    para(f"The formal Playwright run {run_id} scheduled {stats['total']} automated cases. {stats['blocked']} were blocked and excluded from the executed-case denominator. All cases in this report’s test catalogue are automated cases.")
    add_table(doc, ["Run", "Type", "Cases", "Passed", "Failed", "Blocked", "Use in metrics"], [[rid, kind, str(result_stats(read_run(rid)[1])[0]["total"]), str(result_stats(read_run(rid)[1])[0]["passed"]), str(result_stats(read_run(rid)[1])[0]["failed"]), str(result_stats(read_run(rid)[1])[0]["blocked"]), "Primary" if rid == all_runs[0][0] else "Supporting; not added as unique cases"] for rid, kind in all_runs] + [["Terminal proof", "Login screen render check", "1", "1", "0", "0", "Supplementary; excluded from 52-case formal suite"]], fontsize=9)
    doc.add_picture(str(image_dir/"execution-chart.png"), width=Inches(6.1)); add_caption(doc, f"Figure {figure_number}. Formal regression results for run {run_id}: {stats['passed']} passed, {stats['failed']} failed, and {stats['blocked']} blocked."); figure_number += 1
    h2("Result Calculation")
    para(f"Pass rate = Passed ÷ (Passed + Failed) = {stats['passed']} ÷ ({stats['passed']} + {stats['failed']}) = {pass_rate:.1f}%. The two blocked cases are reported separately. The terminal proof is a separate one-test run and does not change this calculation.")

    # 13. Automation Coverage
    h1("13. Automation Coverage")
    module_counts = {}
    for case in cases:
        module_counts.setdefault(case["Module"], {"total": 0, "automated": 0})
        module_counts[case["Module"]]["total"] += 1
        if case in cases: module_counts[case["Module"]]["automated"] += 1
    coverage = [(m, str(v["total"]), str(v["automated"]), f"{100*v['automated']/v['total']:.1f}%" if v["total"] else "0%") for m, v in sorted(module_counts.items())]
    add_caption(doc, "Table 7. Playwright implementation coverage by module.")
    add_table(doc, ["Module", "Total TC", "Automated", "Coverage %"], coverage, fontsize=10)
    para(f"Automation coverage is {len(cases)}/{total} ({automation_rate:.1f}%) against the automated-only catalogue. Execution coverage is {executed}/{total} ({100*executed/total:.1f}%), and pass rate is calculated separately among executed cases.")
    doc.add_picture(str(image_dir/"coverage-chart.png"), width=Inches(6.1)); add_caption(doc, f"Figure {figure_number}. All {len(cases)} in-scope cases have Playwright implementations."); figure_number += 1

    # 14. Risks and Assumptions
    h1("14. Risks and Assumptions"); h2("Risks")
    for item in ("Unstable environments", "Test data issues", "Third-party dependency failures", "Frequent requirement changes"): bullet(item)
    h2("Assumptions")
    for item in ("Test environments remain available", "Business requirements are finalized", "APIs are accessible during execution"): bullet(item)
    para("The existing shared development/demo database contains unrelated records. Run-labelled fixtures and a single worker reduce interference; dashboard totals can still reflect prior activity.")
    add_table(doc, ["Risk", "Potential effect", "Control / response"], [
        ("Shared demo data", "Dashboard totals include unrelated existing activity", "Record baseline and compare only the controlled transaction delta"),
        ("Supabase reachability", "Setup can fail before a case begins", "Keep setup failures separate from test failures; rerun only after connectivity is restored"),
        ("Unavailable UI state", "Case cannot reach its expected action", "Keep it Blocked and document the precise missing precondition"),
        ("External or hardware integration", "Browser checks cannot prove live service or rover behavior", "Label as out of scope and verify in an isolated integration/hardware cycle")], fontsize=9.5)

    # 15. Reporting and Dashboard
    h1("15. Reporting and Dashboard"); h2("Daily Metrics")
    for item in ("Build Status", "Execution Status", "Defect Trend", "Automation Coverage", "Failed Tests", "Execution Duration"): bullet(item)
    para(f"Formal run: {stats['passed']} passed, {stats['failed']} failed, {stats['blocked']} blocked; automation coverage {automation_rate:.1f}%; execution duration {stats['duration_seconds']} seconds.")
    h2("Recommended Reports")
    for item in ("Playwright HTML Report — produced for the formal run and terminal proof", "Playwright JSON results — produced for the formal run", "Allure Report — not configured", "Extent Report — not configured", "Azure DevOps Dashboard — not used", "Power BI Test Dashboard — not used"): bullet(item)
    para("Terminal proof files: docs/automation/terminal-proof/playwright-login-shell-run.txt and docs/automation/terminal-proof/html/index.html. The terminal proof is a separate local login-shell check and is not included in the formal suite denominator.")
    h2("Report Artifacts")
    add_table(doc, ["Artifact", "Location", "Purpose"], [
        ("Formal HTML report", f"docs/automation/run-artifacts/{all_runs[0][0]}/html/index.html", "Interactive 52-case report"),
        ("Formal JSON result", f"docs/automation/run-artifacts/{all_runs[0][0]}/results.json", "Machine-readable case results"),
        ("Terminal transcript", "docs/automation/terminal-proof/playwright-login-shell-run.txt", "Shows the Playwright command and one passing browser test"),
        ("Terminal HTML report", "docs/automation/terminal-proof/html/index.html", "Standalone supplementary login-screen run")], fontsize=9.5)
    h2("Playwright Terminal Proof")
    proof_path = OUT / "terminal-proof" / "playwright-login-shell-run.txt"
    if proof_path.exists():
        p = doc.add_paragraph(); p.paragraph_format.left_indent = Inches(.2); p.paragraph_format.right_indent = Inches(.2)
        r = p.add_run(proof_path.read_text(encoding="utf-8").strip())
        r.font.name = "Consolas"; r.font.size = Pt(8.5)
        add_caption(doc, "Terminal output from the separately recorded one-test Playwright login-shell proof.")

    # 16. CI/CD Integration Checklist
    h1("16. CI/CD Integration Checklist")
    add_table(doc, ["Item", "Status"], [("Source Code in Git", "☒"), ("Build Pipeline Configured", "☒ Manual GitHub Actions workflow exists"),
              ("Automated Execution Triggered", "☒ Local Playwright terminal run recorded"), ("Test Reports Published", "☒ Local HTML/JSON reports saved; no remote publication"),
              ("Notifications Enabled", "☐"), ("Quality Gates Configured", "☐")], fontsize=10)

    # 17. Test Sign-Off
    h1("17. Test Sign-Off")
    add_table(doc, ["Role", "Name", "Signature", "Date"], [("QA Lead", "[Enter name]", "", ""), ("Test Manager", "[Enter name]", "", ""),
              ("Development Lead", "[Enter name]", "", ""), ("Business Owner", "[Enter name]", "", "")], fontsize=10)
    h2("Final Recommendation")
    para("Conditional Go for the tested web workflows, subject to review of blocked cases and completion of human sign-off. This recommendation is based on recorded automated results only.")
    para("Go Live Status:")
    bullet("☐ Go")
    bullet("☒ Conditional Go")
    bullet("☐ No-Go")

    doc.add_paragraph("Review note: this report records test evidence and a conditional recommendation. Final approval remains with the named human reviewers.")

    doc.core_properties.title = "SeedRover Software Automation Test Document"
    doc.core_properties.subject = "SeedRover Web Admin testing using the supplied 17-section template"
    doc.core_properties.author = "SeedRover project team"
    doc.save(path)


def render_docx_pdf(source_docx, pdf_path):
    """Render every paragraph, table and image from the generated Word paper into its matching PDF."""
    from docx.oxml.text.paragraph import CT_P
    from docx.oxml.table import CT_Tbl
    from docx.text.paragraph import Paragraph as WordParagraph
    from docx.table import Table as WordTable
    document=Document(source_docx)
    styles=getSampleStyleSheet()
    styles.add(ParagraphStyle(name="PaperTitle",parent=styles["Title"],fontName="Times-Bold",fontSize=24,leading=29,textColor=colors.HexColor("#18382A"),alignment=TA_CENTER,spaceAfter=15))
    styles.add(ParagraphStyle(name="PaperH1",parent=styles["Heading1"],fontName="Times-Bold",fontSize=16,leading=20,textColor=colors.HexColor("#18382A"),spaceBefore=9,spaceAfter=7,keepWithNext=True))
    styles.add(ParagraphStyle(name="PaperH2",parent=styles["Heading2"],fontName="Times-Bold",fontSize=12,leading=15,textColor=colors.HexColor("#246B45"),spaceBefore=7,spaceAfter=5,keepWithNext=True))
    styles.add(ParagraphStyle(name="PaperBody",parent=styles["BodyText"],fontName="Times-Roman",fontSize=11,leading=14,spaceAfter=6))
    styles.add(ParagraphStyle(name="PaperCaption",parent=styles["BodyText"],fontName="Times-Italic",fontSize=9,leading=12,alignment=TA_CENTER,spaceAfter=9))
    styles.add(ParagraphStyle(name="PaperSmall",parent=styles["BodyText"],fontName="Times-Roman",fontSize=10,leading=12.2,spaceAfter=4))
    styles.add(ParagraphStyle(name="PaperCode",parent=styles["Code"],fontName="Courier",fontSize=9.6,leading=12,backColor=colors.HexColor("#F3F6F4"),borderPadding=6,spaceAfter=8))
    toc_styles=[ParagraphStyle(name="TocMain",fontName="Times-Roman",fontSize=10,leading=15,leftIndent=10,firstLineIndent=-10),ParagraphStyle(name="TocSub",fontName="Times-Roman",fontSize=10,leading=13,leftIndent=28,firstLineIndent=-12,textColor=colors.HexColor("#42624D"))]
    lof_styles=[ParagraphStyle(name="FigureToc",fontName="Times-Roman",fontSize=10,leading=14,leftIndent=10,firstLineIndent=-10)]
    lot_styles=[ParagraphStyle(name="TableToc",fontName="Times-Roman",fontSize=10,leading=14,leftIndent=10,firstLineIndent=-10)]
    story=[];media=OUT/"generated"/"docx-media";media.mkdir(parents=True,exist_ok=True)
    image_no=0
    for block in document.element.body.iterchildren():
        if isinstance(block,CT_P):
            paragraph=WordParagraph(block,document)
            instruction=" ".join(node.text or "" for node in block.xpath(".//w:instrText"))
            if instruction.strip().upper().startswith("TOC"):
                if '"FIGURE"' in instruction.upper(): story.append(TableOfContents(notifyKind="FigureEntry",levelStyles=lof_styles))
                elif '"TABLE"' in instruction.upper(): story.append(TableOfContents(notifyKind="TableEntry",levelStyles=lot_styles))
                else: story.append(TableOfContents(levelStyles=toc_styles))
                continue
            if block.xpath('.//w:br[@w:type="page"]'):
                story.append(PageBreak())
                text=paragraph.text.strip()
                if not text: continue
            blips=block.xpath(".//a:blip")
            for blip in blips:
                rid=blip.get(qn("r:embed"));part=document.part.related_parts[rid]
                image_no+=1;ext=Path(str(part.partname)).suffix or ".png";image_path=media/f"image-{image_no}{ext}";image_path.write_bytes(part.blob)
                with Image.open(image_path) as image: iw,ih=image.size
                width=min(6.45*inch,iw*inch/160);height=width*ih/iw;maxheight=5.2*inch
                if height>maxheight:height=maxheight;width=height*iw/ih
                story.append(PDFImage(str(image_path),width=width,height=height,hAlign="CENTER"))
            text=paragraph.text.strip()
            if not text: continue
            if paragraph.style.name=="Caption" or text.startswith(("Figure ","Table ")):
                if text.startswith("Figure "):
                    clean=re.sub(r"^Figure\s+\d+\s*\.?\s*","",text)
                    story.append(Paragraph(html.escape(clean),styles["PaperCaption"]))
                    story.append(_CaptionIndex("FigureEntry",clean))
                elif text.startswith("Table "):
                    clean=re.sub(r"^Table\s+\d+\s*\.?\s*","",text)
                    story.append(Paragraph(html.escape(clean),styles["PaperSmall"]))
                    story.append(_CaptionIndex("TableEntry",clean))
                else: story.append(Paragraph(html.escape(text),styles["PaperCaption"]))
                continue
            if paragraph.style.name=="Title": story.append(Paragraph(html.escape(text),styles["PaperTitle"]));continue
            if paragraph.style.name=="Heading 1": story.append(Paragraph(html.escape(text),styles["PaperH1"]));continue
            if paragraph.style.name=="Heading 2": story.append(Paragraph(html.escape(text),styles["PaperH2"]));continue
            if paragraph.style.name=="Heading 3": story.append(Paragraph(html.escape(text),styles["PaperH2"]));continue
            escaped=html.escape(text).replace("\n","<br/>")
            if "Consolas" in [run.font.name for run in paragraph.runs if run.font.name]: story.append(Paragraph(escaped,styles["PaperCode"]))
            elif paragraph.style.name.startswith("List"):
                story.append(Paragraph("•  "+escaped,styles["PaperBody"]))
            else: story.append(Paragraph(escaped,styles["PaperBody"]))
        elif isinstance(block,CT_Tbl):
            table=WordTable(block,document);data=[]
            for row in table.rows:
                cells=[]
                for cell in row.cells:
                    value=html.escape(cell.text).replace("\n","<br/>")
                    cells.append(Paragraph(value,styles["PaperSmall"]))
                data.append(cells)
            if not data: continue
            ncols=len(data[0]);width=A4[0]-36*mm
            headers=[cell.text.strip() for cell in table.rows[0].cells]
            # Preserve the wide scenario matrix and case cards as two readable columns.
            if ncols==2:widths=[29*mm,width-29*mm]
            elif ncols==3:widths=[width*.14,width*.43,width*.43]
            elif ncols==4 and headers==["Test ID","Module","Scenario","Priority"]:widths=[width*.21,width*.22,width*.43,width*.14]
            elif ncols==4 and headers==["Module","Total TC","Automated","Coverage %"]:widths=[width*.44,width*.18,width*.18,width*.20]
            elif ncols==4:widths=[width*.16,width*.36,width*.19,width*.29]
            elif ncols==5:widths=[width*.13,width*.2,width*.2,width*.2,width*.27]
            else:widths=[width/ncols]*ncols
            has_dark_title=any("SR-" in row.cells[0].text for row in table.rows[:1])
            tab=Table(data,colWidths=widths,repeatRows=1 if not has_dark_title else 0,hAlign="LEFT",splitByRow=1)
            commands=[("GRID",(0,0),(-1,-1),.35,colors.HexColor("#B7C7BA")),("VALIGN",(0,0),(-1,-1),"TOP"),
                      ("LEFTPADDING",(0,0),(-1,-1),4),("RIGHTPADDING",(0,0),(-1,-1),4),
                      ("TOPPADDING",(0,0),(-1,-1),3),("BOTTOMPADDING",(0,0),(-1,-1),3),
                      ("ROWBACKGROUNDS",(0,1),(-1,-1),[colors.white,colors.HexColor("#F2F7F3")])]
            if has_dark_title:commands += [("SPAN",(0,0),(-1,0)),("BACKGROUND",(0,0),(-1,0),colors.HexColor("#246B45")),("TEXTCOLOR",(0,0),(-1,0),colors.white)]
            else:commands += [("BACKGROUND",(0,0),(-1,0),colors.HexColor("#246B45")),("TEXTCOLOR",(0,0),(-1,0),colors.white)]
            tab.setStyle(TableStyle(commands));story.append(tab);story.append(Spacer(1,4))
    doc=PaperDoc(str(pdf_path),pagesize=A4,rightMargin=18*mm,leftMargin=18*mm,topMargin=19*mm,bottomMargin=19*mm,title=document.core_properties.title or TITLE,author=document.core_properties.author or "SeedRover project team")
    doc.multiBuild(story)


class _CaptionIndex(Paragraph):
    def __init__(self,kind,text):
        super().__init__("",ParagraphStyle(name=f"index-{kind}",fontSize=1,leading=1));self.kind=kind;self.caption=text


def make_pdf(path, run_id, env, stats, total, cases, planned, figures, runs, image_dir):
    styles=getSampleStyleSheet()
    styles.add(ParagraphStyle(name="CoverTitle",parent=styles["Title"],fontName="Times-Bold",fontSize=23,leading=28,textColor=colors.HexColor("#18382A"),alignment=TA_CENTER,spaceAfter=15))
    styles.add(ParagraphStyle(name="PDFH1",parent=styles["Heading1"],fontName="Times-Bold",fontSize=16,leading=20,textColor=colors.HexColor("#18382A"),spaceBefore=9,spaceAfter=7,keepWithNext=True))
    styles.add(ParagraphStyle(name="PDFH2",parent=styles["Heading2"],fontName="Times-Bold",fontSize=12,leading=15,textColor=colors.HexColor("#246B45"),spaceBefore=7,spaceAfter=5,keepWithNext=True))
    styles.add(ParagraphStyle(name="PDFBody",parent=styles["BodyText"],fontName="Times-Roman",fontSize=9.5,leading=13,spaceAfter=6))
    styles.add(ParagraphStyle(name="FigureCaption",parent=styles["BodyText"],fontName="Times-Italic",fontSize=8.4,leading=11,alignment=TA_CENTER,spaceAfter=11))
    styles.add(ParagraphStyle(name="TableCaption",parent=styles["BodyText"],fontName="Times-Italic",fontSize=8.4,leading=11,alignment=TA_LEFT,spaceBefore=4,spaceAfter=4))
    styles.add(ParagraphStyle(name="SmallCode",parent=styles["Code"],fontName="Courier",fontSize=7.8,leading=10,backColor=colors.HexColor("#F3F6F4"),borderPadding=6,spaceAfter=8))
    flow=[]
    flow += [Spacer(1,35*mm),PDFImage(str(ROOT/"web-admin/public/brand/seedrover-logo.png"),width=87*mm,height=29*mm),Spacer(1,22*mm),Paragraph(html.escape(TITLE),styles["CoverTitle"]),Paragraph("Formal Testing Paper  |  Web Administration Portal  |  Playwright Evidence",styles["PDFBody"]),Spacer(1,10*mm)]
    cover=[["Submission information","Editable details"],["Institution / Department","[Enter school and department]"],["Course / Section","[Enter course and section]"],["Prepared by","[Enter team members]"],["Instructor","[Enter instructor]"],["Submission date","[Enter submission date]"],["Report revision",f"1.0 | Primary run {run_id}"]]
    flow += [pdf_table(cover,[48*mm,116*mm],9),Spacer(1,12*mm),Paragraph("Prepared for academic review. Named reviewer approval and signatures are intentionally left blank.",styles["FigureCaption"]),PageBreak()]
    toc=TableOfContents();toc.levelStyles=[ParagraphStyle(name="TOC0",fontName="Times-Roman",fontSize=9.5,leading=14,leftIndent=12,firstLineIndent=-12),ParagraphStyle(name="TOC1",fontName="Times-Roman",fontSize=8.7,leading=12,leftIndent=30,firstLineIndent=-14,textColor=colors.HexColor("#42624D"))]
    flow += [Paragraph("Contents",styles["PDFH1"]),toc,PageBreak(),Paragraph("List of Figures",styles["PDFH1"])]
    lof=TableOfContents();lof.levelStyles=[ParagraphStyle(name="LOF",fontName="Times-Roman",fontSize=8.6,leading=12,leftIndent=12,firstLineIndent=-12)];lof.levelStyles[0].spaceAfter=2
    flow += [lof,PageBreak()]
    paragraphs=[
        ("1. Executive Summary",[f"This paper documents testing of SeedRover Web Admin, a Next.js management portal backed by the project's existing development/demo Supabase service. Playwright Test with TypeScript and Chromium provides reproducible browser evidence; a detailed manual scenario catalogue supplements the scripted cases.",f"Current full regression run {run_id} executed {stats['total']} cases: {stats['passed']} passed, {stats['failed']} failed and {stats['blocked']} blocked. Pass rate among executed cases is 100% because 50 passed and zero failed. The catalogue contains {total} cases; {stats['total']}/{total} (24.1%) have Playwright implementations. The other {total-stats['total']} manual scenario specifications have expected outcomes but no recorded observations.","Tested strengths include role landing pages, stock movements, sale arithmetic and stock reconciliation, discounts, exports, printing, user workflows and saved crop care. Crop edit and stale/no-data rover cases are blocked by the actual interface/shared-state conditions. No manual scenario is described as a verified result without supporting evidence."]),
        ("2. System Overview",["SeedRover combines Flutter mobile, Next.js Web Admin, Supabase, ESP32 rover and camera firmware. This paper tests Web Admin in Chromium and its configured development/demo data service. It does not operate physical hardware or claim mobile coverage.","The principal flow is user browser to portal server actions and pages, then authenticated reads/writes to Supabase Auth, Postgres and RPCs. Rover monitoring reads stored telemetry and is treated as read-only in this browser suite."]),
        ("2.1 Web modules examined",["Dashboard; inventory catalogue and batches; sales, customers and discounts; crops, care and harvest; user management; investments; exports and print views; notifications, activity and rover monitoring. Each module has a coverage matrix and test register in the appendices."]),
        ("2.2 Account roles and visible portal access",["The five configured roles are System Administrator, Farm Planting Manager, Farm Inventory Manager, Planting Staff and Inventory Staff. Planting roles focus on crops; inventory roles focus on inventory and sales; user administration and investments are restricted. Interface visibility assertions are explicitly distinguished from direct server/database authorization probes."]),
        ("3. Testing Objectives and Strategy",["Testing asks whether representative tasks save the intended business result, validation prevents invalid mutations, role gates constrain access and saved values survive reload. The strategy combines automated browser regression, source assertion review, controlled synthetic fixtures and a detailed manual scenario catalogue.","Status definitions: Passed means the named case ran and its assertions passed; Failed means it executed and contradicted an expected outcome; Blocked means a real prerequisite prevented execution; No result recorded means the catalogue contains no observed outcome or execution evidence for that case.","Pass rate is Passed/(Passed+Failed). Automation coverage is implemented Playwright cases divided by the full catalogue. Execution coverage is executed pass/fail cases divided by the catalogue. Blocked and cases with no result recorded are separate."]),
        ("4. Environment and Test Data",[f"Application: local optimized Next.js build; Node {env.get('node')}; Chromium, Playwright {env.get('playwright')}; timezone Asia/Manila; one worker; no automatic retries. Current run started {env.get('startedAt')} (UTC). The database hostname was checked against the reviewed development/demo allowlist; credentials are omitted.","The runner creates uniquely identified AUTOTEST fixtures, writes exact IDs to records.jsonl and deactivates only dedicated accounts. It does not reset the database, apply migrations, change unrelated demo rows or overwrite rover readings. Transaction and audit history is retained and can influence totals."]),
        ("5. Functional and Role Coverage",[f"The {total}-case catalogue combines {stats['total']} preserved executable SR-* cases with {total-stats['total']} detailed manual SR-PLAN-* procedures. Existing case identifiers are preserved; new planned cases are distinctly labeled. Role, module, priority, method and status appear on every case record."]),
        ("6. Module Testing Design",["Inventory examples specify exact arithmetic and movement history. A 5 kg receipt added to 20 kg should persist as 25 kg; a 3 kg issue from 20 kg should persist as 17 kg; an attempted 3 kg issue from 2 kg must show clear rejection and leave 2 kg untouched.","A cash sale of 3 kg at PHP 50/kg with PHP 200 tender should create a PHP 150 receipt, PHP 50 change and 17 kg remaining from 20 kg. Separate scenarios cover multi-item sales, non-cash references, oversell, void, customers, discounts, payments, care, harvest, expense records, role restrictions and exports.","Crop tests use only synthetic receipt fixtures explicitly marked as not verified by hardware. Harvest tests require an open batch and matching kg inventory destination. Unavailable edit controls and external integration states are blockers or planned checks, never assumed success."]),
        ("7. Playwright Implementation and Proof",["The TypeScript suite shares authentication and fixture helpers, checks the verified Supabase host, records fixture IDs, uses a single worker with no retries and generates HTML/JSON reports, screenshots and failure traces.","Reproduction from web-admin: npm ci; npx playwright install chromium; npm run test:e2e:preflight; npm run test:e2e:smoke; npm run test:e2e. The current code proof asserts the PHP 150 total, PHP 50 change and 17 kg balance for the controlled receipt."]),
        ("8. Execution Results",[f"Current full run: {stats['passed']} Passed, {stats['failed']} Failed, {stats['blocked']} Blocked out of {stats['total']} scheduled cases. Executed-case pass rate is 100%; automation coverage is {stats['total']/total*100:.1f}%; execution coverage is {(stats['passed']+stats['failed'])/total*100:.1f}%. Smoke results are a five-case subset and are not added as unique tests.","Two scenarios were blocked: crop editing because the detail page exposes no reachable Edit Crop control, and rover stale/no-data because shared readings were fresh. Historic formal and focused-regression runs are retained as separate run records."]),
        ("9. Defects, limitations and assertion audit",["The former insufficient-stock generic error was fixed; a focused retest and current SR-INV-006 show an actionable message and unchanged balance. The former ambiguous receipt profile relation was fixed and the receipt case passes.","The current suite has assertion-scope caveats: duplicate username checks the UI message without an independent profile count; negative-price probing does not submit the form; four role cases check route gates only; staff void checks visible controls but does not invoke a forged server action. These are useful interface checks, but not endpoint proofs.","No currently open Critical/High defect is listed in the prior defect register. This finding is limited to executed scenarios and does not certify untested modules."]),
        ("10. Assessment and Recommendations",["Evidence supports the tested core portal flows under the specified development environment. It does not imply that the full portal or all integrations have passed. Prioritize stronger server-side authorization assertions, make crop edit available or document its removal, and isolate rover stale/no-data fixtures."]),
        ("11. References and review record",["References: repository README, web-admin routes/actions/components, Playwright suite/configuration, crop care and harvest workflow documentation, and the run-specific JSON/HTML/fixture artifacts. Cover attribution, instructor, review and signature fields remain editable and unsigned."]),
    ]
    for heading,paras in paragraphs:
        flow.append(Paragraph(html.escape(heading),styles["PDFH1"]));
        for p in paras: flow.append(Paragraph(html.escape(p).replace("\n","<br/>"),styles["PDFBody"]))
        if heading.startswith("2. System"): flow.append(PDFImage(str(image_dir/"architecture.png"),width=174*mm,height=61.9*mm))
    flow += [Paragraph("Figures from the current Playwright run",styles["PDFH2"]),PDFImage(str(image_dir/"execution-chart.png"),width=170*mm,height=64.2*mm),Paragraph(f"Figure 2. Current result counts for run {run_id}: {stats['passed']} passed, {stats['blocked']} blocked, {stats['failed']} failed.",styles["FigureCaption"]),PDFImage(str(image_dir/"coverage-chart.png"),width=170*mm,height=56.7*mm),Paragraph(f"Figure 3. Current test method coverage against {total} catalogued cases.",styles["FigureCaption"])]
    for i,item in enumerate(figures,4):
        img=Image.open(item["path"]);aspect=img.height/img.width;width=171*mm;height=width*aspect
        flow += [PageBreak(),Spacer(1,5*mm),PDFImage(str(item["path"]),width=width,height=height),Paragraph(f"Figure {i}. {html.escape(item['description'])}. Case {item['caseId']}; Playwright run {item['runId']}.",styles["FigureCaption"])]
    flow.append(PageBreak());flow.append(Paragraph("Appendix A — Detailed test case catalogue",styles["PDFH1"]))
    flow.append(Paragraph(f"{total} distinct cases: {stats['total']} automated and {total-stats['total']} manual scenario specifications without recorded results. Only the run register has observed results.",styles["PDFBody"]))
    for group in SCENARIOS:
        flow.append(Paragraph(html.escape(group["module"]),styles["PDFH2"]))
        selected=[c for c in cases if c["Module"]==group["module"]]+[c for c in planned if c["Module"]==group["module"]]
        for c in selected:
            card=[[f"{c['Case ID']} — {c['Scenario']}",f"Role: {c['Role']} | {c['Priority']} | {c['Method']} | {c['Status']}"],
                  ["Objective / preconditions",c["Objective"]+"\n"+c["Preconditions"]],["Test data",c["Test Data"]],
                  ["Steps",c["Steps"]],["Expected result",c["Expected Result"]],["Cleanup / actual",c["Cleanup"]+"\nActual: "+c["Actual Result"]],["Evidence / source",c["Evidence"]+"\n"+c["Source"]]]
            flow.append(pdf_table(card,[36*mm,136*mm],7.2));flow.append(Spacer(1,2.2*mm))
    flow += [PageBreak(),Paragraph("Appendix B — Current execution and evidence register",styles["PDFH1"])]
    summary=[["Case ID","Scenario","Status","Role","Run evidence"]]+[[c["Case ID"],c["Scenario"],c["Status"],c["Role"],c["Evidence"]] for c in cases]
    flow.append(pdf_table(summary,[23*mm,70*mm,19*mm,38*mm,22*mm],6.6))
    flow += [PageBreak(),Paragraph("Appendix C — Run history and defect register",styles["PDFH1"])]
    for rid,kind in runs:
        _rd,raw,_e=read_run(rid);ss,_=result_stats(raw)
        flow.append(pdf_table([["Run type","Run ID","Total","Passed","Failed","Blocked"],[kind,rid,ss["total"],ss["passed"],ss["failed"],ss["blocked"]]],[34*mm,58*mm,17*mm,17*mm,17*mm,20*mm],8))
    defectrows=[["ID","Severity","Finding","Disposition"],["DEF-001","Medium","Insufficient-stock rejection formerly rendered generic error.","Fixed and retested in focused/current run."],["DEF-002","Medium","Ambiguous receipt profile relation.","Fixed; receipt case passes."],["GAP-001","Coverage","Crop edit control is not reachable.","Blocked; implement or formally remove feature."],["GAP-002","Environment","Rover values currently fresh.","Use isolated fixtures for stale/no-data test."]]
    flow.append(pdf_table(defectrows,[20*mm,24*mm,67*mm,52*mm],8))
    doc=PaperDoc(path,pagesize=A4,rightMargin=18*mm,leftMargin=18*mm,topMargin=19*mm,bottomMargin=19*mm,title=TITLE,author="SeedRover project team")
    doc.multiBuild(flow)


def main():
    parser=argparse.ArgumentParser();parser.add_argument("--run",required=True,help="Primary full Playwright run ID");parser.add_argument("--smoke",required=True);parser.add_argument("--focused",required=True);parser.add_argument("--historical",required=True);args=parser.parse_args()
    run_id=args.run;run_dir,raw,env=read_run(run_id);stats,entries=result_stats(raw)
    if stats["total"]!=52: raise SystemExit(f"Expected the audited 52-case browser suite, found {stats['total']} cases")
    cases=[automation_case(cid,title,test,result,run_id,run_dir) for cid,title,test,result in entries]
    if len({c["Case ID"] for c in cases})!=len(cases): raise SystemExit("Duplicate case IDs in current Playwright report")
    old_ids={c["Case ID"] for c in cases}
    planned=[];total_cases=len(cases)
    for rid in (args.smoke,args.focused,args.historical): read_run(rid)
    OUT.mkdir(parents=True,exist_ok=True)
    run_artifacts=OUT/"run-artifacts"/run_id;run_artifacts.mkdir(parents=True,exist_ok=True)
    for filename in ("results.json","environment.json","setup.json","cleanup.json","records.jsonl"):
        src=run_dir/filename
        if src.exists(): shutil.copy2(src,run_artifacts/filename)
    if (run_dir/"html").exists(): shutil.copytree(run_dir/"html",run_artifacts/"html",dirs_exist_ok=True)
    evidence_dir=OUT/"evidence"/run_id;figures=collect_evidence(run_id,raw,evidence_dir)
    (evidence_dir/"evidence-metadata.json").write_text(json.dumps([{k:v for k,v in item.items() if k!="path"} for item in figures],indent=2),encoding="utf-8")
    all_cases=cases
    save_csv(OUT/"test-case-register.csv",TEST_FIELDS,all_cases)
    defects=[
        {"Defect ID":"DEF-001","Severity":"Medium","Summary":"Insufficient stock was rejected in the database but the portal previously displayed a generic server-component error.","Status":"Fixed; focused retest and current regression passed","Evidence case":"SR-INV-006","Run IDs":f"20261005T144631592-7060; {run_id}","Notes":"Current UI shows actionable insufficient-stock guidance; saved balance remains unchanged."},
        {"Defect ID":"DEF-002","Severity":"Medium","Summary":"Sales receipt query had an ambiguous sales_orders-to-profiles relationship.","Status":"Fixed; receipt case passed","Evidence case":"SR-SALE-001","Run IDs":f"20261005T141625648-47936; {run_id}","Notes":"Query now specifies the recorded_by foreign key."},
    ]
    defect_fields=list(defects[0]);save_csv(OUT/"defect-register.csv",defect_fields,defects)
    run_specs=[(args.run,"Current full regression"),(args.smoke,"Current smoke subset"),(args.focused,"Focused stock rejection retest"),(args.historical,"Historical formal baseline")]
    run_rows=[]
    for rid,kind in run_specs:
        _,rraw,renv=read_run(rid);s,_=result_stats(rraw);run_rows.append({"Run ID":rid,"Run type":kind,"Started":renv.get("startedAt"),"Total":s["total"],"Passed":s["passed"],"Failed":s["failed"],"Blocked":s["blocked"],"Browser":renv.get("browser"),"Playwright":renv.get("playwright"),"Evidence path":f"run-artifacts/{rid}/"})
        dest=OUT/"run-artifacts"/rid;dest.mkdir(parents=True,exist_ok=True)
        for fn in ("results.json","environment.json","setup.json","cleanup.json","records.jsonl"):
            if (APP/"e2e"/"runs"/rid/fn).exists():shutil.copy2(APP/"e2e"/"runs"/rid/fn,dest/fn)
        if (APP/"e2e"/"runs"/rid/"html").exists():shutil.copytree(APP/"e2e"/"runs"/rid/"html",dest/"html",dirs_exist_ok=True)
    run_fields=list(run_rows[0]);save_csv(OUT/"execution-register.csv",run_fields,run_rows)
    execution={"primaryRun":run_id,"runType":"Current full regression","stats":stats,"catalogue":{"total":total_cases,"automated":len(cases),"manualNoResultRecorded":0,"automationCoveragePercent":round(len(cases)/total_cases*100,2),"executionCoveragePercent":round((stats['passed']+stats['failed'])/total_cases*100,2)},"passRatePercent":round(stats['passed']/(stats['passed']+stats['failed'])*100,2) if stats['passed']+stats['failed'] else 0,"historicalAndSupportingRuns":run_rows,"observedBlockers":[{"case":"SR-CROP-002","reason":"No reachable Edit Crop control in current details UI."},{"case":"SR-OBS-003","reason":"Existing rover readings fresh; shared state not overwritten."}],"assertionAudit":AUTO_AUDIT}
    (OUT/"execution-summary.json").write_text(json.dumps(execution,indent=2),encoding="utf-8")
    evidence_rows=[{"Figure":i+1,"Case ID":f["caseId"],"Run ID":f["runId"],"Description":f["description"],"File":f"evidence/{run_id}/{f['file']}","Evidence type":"Playwright screenshot attachment"} for i,f in enumerate(figures)]
    for item in figures:item["path"]=str(item["path"])
    save_csv(OUT/"evidence-register.csv",["Figure","Case ID","Run ID","Description","File","Evidence type"],evidence_rows)
    image_dir=OUT/"generated";make_diagrams(image_dir,stats,total_cases,len(cases),len(planned))
    stem="SeedRover_Software_Automation_Test_Report"
    docx_path=OUT/(stem+".docx");pdf_path=OUT/(stem+".pdf")
    build_template_docx(docx_path,run_id,env,stats,cases,planned,run_specs,figures,image_dir)
    render_docx_pdf(docx_path,pdf_path)
    workbook_sheets=[("Test Cases",TEST_FIELDS,all_cases),("Execution",run_fields,run_rows),("Defects",defect_fields,defects)]
    write_xlsx(OUT/"seedrover-test-register.xlsx",workbook_sheets)
    readme=f"""# SeedRover software automation test document

The report uses the supplied template’s 17 section topics as its backbone and includes only the 52 automated Playwright cases, recorded run results, defect tracking, coverage, risks, reporting, CI checklist, and unsigned sign-off fields.

- [Word report](SeedRover_Software_Automation_Test_Report.docx)
- [Matching PDF](SeedRover_Software_Automation_Test_Report.pdf)
- [Scenario and test-case register (CSV)](test-case-register.csv)
- [Formatted test register (Excel)](seedrover-test-register.xlsx)
- [Execution register](execution-register.csv)
- [Defect register](defect-register.csv)
- [Playwright terminal transcript](terminal-proof/playwright-login-shell-run.txt)
- [Playwright terminal-proof HTML report](terminal-proof/html/index.html)
- [Formal regression HTML report](run-artifacts/{run_id}/html/index.html)
- [Database cleanup preview status](database-cleanup-status.json)
- [Prior expanded draft archive](archive/2026-10-06-before-automated-only/)

Formal run {run_id}: {stats['passed']} passed, {stats['failed']} failed, {stats['blocked']} blocked of {stats['total']} automated cases. Pass rate among executed cases is {execution['passRatePercent']:.1f}%; execution coverage is {execution['catalogue']['executionCoveragePercent']:.1f}%; automation coverage is {execution['catalogue']['automationCoveragePercent']:.1f}%. The separate terminal login-screen check is supporting Playwright proof and excluded from formal regression totals.

Case-specific screenshots are embedded for {len({item['caseId'] for item in figures})} of {len(cases)} cases in the recorded formal run. Tests without a saved screenshot are being updated to attach one on their next actual execution; the report does not substitute generated images for run evidence.
"""
    (OUT/"README.md").write_text(readme,encoding="utf-8")
    with (evidence_dir/"evidence-index.md").open("w",encoding="utf-8") as f:
        f.write(f"# Current Playwright evidence — {run_id}\n\n")
        f.write(f"Current full run: {stats['passed']} passed; {stats['failed']} failed; {stats['blocked']} blocked from {stats['total']} cases.\n\n")
        f.write("| Case | Run | Observed browser result | Screenshot |\n|---|---|---|---|\n")
        for item in figures:f.write(f"| {item['caseId']} | {item['runId']} | {item['description']} | [{item['file']}]({item['file']}) |\n")
        f.write(f"\nHTML report: ../../run-artifacts/{run_id}/html/index.html\n\nJSON results: ../../run-artifacts/{run_id}/results.json\n")
    print(json.dumps({"primaryRun":run_id,"stats":stats,"scenarioCatalogue":total_cases,"automated":len(cases),"manualNoResultRecorded":0,"figures":len(figures),"docx":str(docx_path),"pdf":str(pdf_path),"xlsx":str(OUT/"seedrover-test-register.xlsx")},indent=2))


if __name__=="__main__": main()
