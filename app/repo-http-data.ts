import {InMemoryDbService} from 'angular-in-memory-web-api';
import {RepoBase} from './repo-base';

export class RepoData implements InMemoryDbService {
  createDb() {
    let ret = [
      new RepoBase({
        name: 'msys2',
        update: '2016-11-21 14:36:05',
        status: 'Success',
        url: 'repo/MSYS2',
        src: 'rsync://mirrors.tuna.tsinghua.edu.cn/msys2'
      }),
      new RepoBase({
        name: 'ubuntu',
        update: '2016-11-21 14:36:05',
        status: 'Failed',
        url: 'repo/ubuntu',
        src: 'rsync://mirrors.tuna.tsinghua.edu.cn/ubuntu'
      })
    ];
    return {ret};
  }
}
