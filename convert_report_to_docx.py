import clean_and_convert

if __name__ == "__main__":
    files = [
        ("FINAL/01_Reports_and_Documentation/IT3081_Final_Consultancy_Report.md",
         "FINAL/01_Reports_and_Documentation/IT3081_Final_Consultancy_Report.docx"),
        ("Courseweb Documents/IT3081_Final_Consultancy_Report.md",
         "Courseweb Documents/IT3081_Final_Consultancy_Report.docx")
    ]
    for md, docx_f in files:
        clean_and_convert.create_styled_docx(md, docx_f)
