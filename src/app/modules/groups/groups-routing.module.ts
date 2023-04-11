import { NgModule } from '@angular/core';
import { RouterModule, Routes } from '@angular/router';
import { GroupDetailComponent } from './pages/group-detail/group-detail.component';
import { GroupsComponent } from './pages/groups/groups.component';

const routes: Routes = [
  {
    path: '',
    component: GroupsComponent,
  },
  {
    path: ':id',
    component: GroupDetailComponent
  }
];

@NgModule({
  imports: [RouterModule.forChild(routes)],
  exports: [RouterModule]
})
export class GroupsRoutingModule { }
