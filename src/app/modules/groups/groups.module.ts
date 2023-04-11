import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { GroupsComponent } from './pages/groups/groups.component';
import { SharedModule } from '../shared/shared.module';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { GroupsRoutingModule } from './groups-routing.module';
import { GroupDetailComponent } from './pages/group-detail/group-detail.component';
import { RouterModule } from '@angular/router';
import { InviteFriendsComponent } from './components/invite-friends/invite-friends.component';
import { InvitationsComponent } from './components/invitations/invitations.component';
import { CreateEventComponent } from './components/create-event/create-event.component';
import { GroupSettingsComponent } from './components/group-settings/group-settings.component';

@NgModule({
  declarations: [
    GroupsComponent,
    GroupDetailComponent,
    InviteFriendsComponent,
    InvitationsComponent,
    CreateEventComponent,
    GroupSettingsComponent
  ],
  imports: [
    CommonModule,
    SharedModule,
    FormsModule,
    RouterModule,
    ReactiveFormsModule,
    GroupsRoutingModule
  ]
})
export class GroupsModule { }
