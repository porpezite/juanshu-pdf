export class ScanRoute {
  marker: string = 'scan';
}

export class ManageRoute {
  tool: string = '';

  constructor(tool: string) {
    this.tool = tool;
  }
}

export class ConvertRoute {
  tool: string = '';

  constructor(tool: string) {
    this.tool = tool;
  }
}

export class EditRoute {
  docId: string = '';

  constructor(docId: string) {
    this.docId = docId;
  }
}
