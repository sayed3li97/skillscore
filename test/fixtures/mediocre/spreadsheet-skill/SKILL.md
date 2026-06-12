---
name: csv-to-xlsx
description: >-
  A spreadsheet helper that converts CSV files into formatted XLSX
  workbooks with styled headers and frozen panes.
---

# CSV to XLSX converter

CSV is a widely used data format. This skill turns CSV input into styled
XLSX workbooks.

## Workflow

1. Read the CSV input and detect the delimiter.
2. Create a workbook and write the header row in bold.
3. Freeze the top pane and auto-size the columns.
4. Save the workbook next to the source file.

For the delimiter you can use a comma, or a semicolon, or a tab, or any
single character the source uses.

```csv
name,amount,date
Widgets,120,2031-01-15
```

The output keeps one sheet per input file and uses the file name as the
sheet name.
