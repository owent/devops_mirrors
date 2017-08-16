import {Component, Injectable, Input, OnInit} from '@angular/core';
import {Http} from '@angular/http';
import {Title} from '@angular/platform-browser';

import {RepoBase} from './repo-base';
import {RepoNetService} from './repo-http-service';

@Component({
  moduleId: module.id,
  selector: 'mirrors',
  templateUrl: 'app.component.html?ver=' + Math.floor(Date.now() / 3600000),
  providers: [RepoNetService]
})
export class AppComponent implements OnInit {
  @Input() title: string;
  @Input() error_msg: string;
  @Input() repos: RepoBase[];

  constructor(private repo_http_service: RepoNetService) {}

  ngOnInit() {
    this.getRepoInfo();

    this.repo_http_service.http.get('./package.json')
        .map(res => res.json())
        .subscribe(data => {
          if (data.author) {
            this.setTitle(
                data.author + ' - ' + (data.displayName || data.name));
          } else {
            this.setTitle((data.displayName || data.name));
          }
        });
  }

  setTitle(title: string) {
    this.title = title;
    this.repo_http_service.title.setTitle(title);
  }

  getRepoInfo() {
    this.repo_http_service.getRepos().subscribe(repos => {
      this.repos = repos;
      setTimeout(function() {
        jQuery('[data-toggle=tooltip]').tooltip({html: true});
      }, 100);
    }, error => this.error_msg = error.toString());
  }
}