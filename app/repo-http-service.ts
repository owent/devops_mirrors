// import 'rxjs/Rx'; // adds ALL RxJS statics & operators to Observable

// See node_module/rxjs/Rxjs.js
// Import just the rxjs statics and operators needed for THIS app.

// Statics
import 'rxjs/add/observable/throw';

// Operators
import 'rxjs/add/operator/catch';
import 'rxjs/add/operator/debounceTime';
import 'rxjs/add/operator/distinctUntilChanged';
import 'rxjs/add/operator/map';

import {Injectable} from '@angular/core';
import {Headers, Http, RequestOptions, Response} from '@angular/http';
import {Title} from '@angular/platform-browser';
import {Observable} from 'rxjs/Observable';

import {RepoBase} from './repo-base';

@Injectable()
export class RepoNetService {
  private repo_net_url = 'tools/sync.status.xml';  // URL to sync.status.xml

  constructor(public http: Http, public title: Title) {}

  getRepos(): Observable<RepoBase[]> {
    var headers = new Headers();
    headers.append('Accept', 'application/xml');
    return this.http
        .get(this.repo_net_url + '?date=' + Date.now(), {headers: headers})
        .map(this.extractData)
        .catch(this.handleError);
  }

  private extractData(res: Response) {
    console.log(res);
    let xml_dom = new DOMParser().parseFromString(res.text(), 'text/xml');
    let ret = [];
    let repos = xml_dom.getElementsByTagName('repo');
    for (var i = 0; i < repos.length; ++i) {
      let repo = repos.item(i);
      ret.push(new RepoBase({
        name: repo.getAttribute('name') || 'Anonymous',
        update: repo.getAttribute('update') || 'Unknown',
        status: repo.getAttribute('status') || 'Failed',
        status_detail: repo.getAttribute('status_detail') ||
            repo.getAttribute('status') || '',
        url: repo.getAttribute('url') || 'repo',
        src: repo.getAttribute('src') || 'Unknown',
        log: repo.getAttribute('log') || undefined,
        total_size: repo.getAttribute('total_size') || '',
        speed: repo.getAttribute('speed') || '',
      }));
    }
    return ret;
  }

  private handleError(error: Response|any) {
    // In a real world app, we might use a remote logging infrastructure
    let errMsg: string;
    if (error instanceof Response) {
      errMsg =
          `${error.status} - ${error.statusText || ''}: ${error.toString()}`;
    } else {
      errMsg = error.message ? error.message : error.toString();
    }
    console.error(errMsg + '\n' + error.text);
    return Observable.throw(errMsg);
  }
}