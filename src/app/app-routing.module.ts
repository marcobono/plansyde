import { NgModule } from '@angular/core';
import { RouterModule, Routes } from '@angular/router';
import { LoggedGuard } from 'src/app/core/guards/logged.guard';

const routes: Routes = [
  {
    path: 'login',
    loadChildren: () => import('./modules/login/login.module').then(module => module.LoginModule)
  }, 
  {
    path: 'account',
    canActivate: [LoggedGuard],
    loadChildren: () => import('./modules/account/account.module').then(module => module.AccountModule)
  }, 
  {
    path: 'groups',
    canActivate: [LoggedGuard],
    loadChildren: () => import('./modules/groups/groups.module').then(module => module.GroupsModule)
  },
  {
    path: 'friends',
    canActivate: [LoggedGuard],
    loadChildren: () => import('./modules/friends/friends.module').then(module => module.FriendsModule)
  },
  {
    path: 'events',
    canActivate: [LoggedGuard],
    loadChildren: () => import('./modules/events/events.module').then(module => module.EventsModule)
  },
  {
    path: '**',
    redirectTo: 'account'
  }
];

@NgModule({
  imports: [RouterModule.forRoot(routes)],
  exports: [RouterModule]
})
export class AppRoutingModule { }
