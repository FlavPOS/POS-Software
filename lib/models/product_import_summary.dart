class ProductImportSummary {
  ProductImportSummary({
    this.totalRows = 0,
    this.validRows = 0,
    this.warningRows = 0,
    this.errorRows = 0,
    this.imported = 0,
    this.updated = 0,
    this.skipped = 0,
    this.failed = 0,
    this.picturesMatched = 0,
    this.picturesSaved = 0,
    this.picturesMissing = 0,
    this.picturesFailed = 0,
  });

  int totalRows;
  int validRows;
  int warningRows;
  int errorRows;

  int imported;
  int updated;
  int skipped;
  int failed;

  int picturesMatched;
  int picturesSaved;
  int picturesMissing;
  int picturesFailed;

  int get completed {
    return imported + updated;
  }

  int get processed {
    return imported + updated + skipped + failed;
  }

  bool get hasErrors {
    return errorRows > 0 || failed > 0;
  }

  bool get hasImportedProducts {
    return imported > 0 || updated > 0;
  }
}
