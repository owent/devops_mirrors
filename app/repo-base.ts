export class RepoBase {
  name: string;
  update: string;
  status: string;
  status_detail: string;
  url: string;
  src: string;
  log: string;
  total_size: string;
  speed: string;

  constructor(options: {
    name?: string,
    update?: string,
    status?: string,
    url?: string,
    src?: string,
    log?: string,
    total_size?: string,
    speed?: string,
    status_detail?: string
  } = {}) {
    this.name = options.name || 'anonymous';
    this.update = options.update || '';
    this.status = options.status || '';
    this.url = options.url || ('repo/' + this.name);
    this.src = options.src || 'NONE';
    this.log = options.log;
    this.total_size = this.getHumanSize(options.total_size || '0');
    this.speed = this.getHumanSize(options.speed || '0') + '/s';
    this.status_detail = options.status_detail || '';
  }

  getStatusStyle(): string {
    if ('success' == this.status.toLowerCase() ||
        'ok' == this.status.toLowerCase()) {
      return 'text-success';
    }

    if ('running' == this.status.toLowerCase()) {
      return 'text-warning';
    }

    return 'text-danger';
  }

  getHumanSize(szstr: string): string {
    let sz = parseInt(szstr);
    if (sz <= 0) {
      return '0B';
    }
    // 16GB=>GB
    if (sz > 1073741824) {
      return (Math.floor(sz / 1073741824 * 100) / 100) + 'GB';
    }

    // 16MB => MB
    if (sz > 4194304) {
      return (Math.floor(sz / 1048576 * 100) / 100) + 'MB';
    }

    // 16KB => KB
    if (sz > 4096) {
      return (Math.floor(sz / 1024 * 100) / 100) + 'KB';
    }

    return sz + 'B';
  }
}