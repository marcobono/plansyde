import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FriendsComponent } from './pages/friends/friends.component';
import { FriendsRoutingModule } from './friends-routing.module';
import { SharedModule } from '../shared/shared.module';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { FriendRequestsComponent } from './pages/friend-requests/friend-requests.component';
import { FriendDetailsComponent } from './components/friend-details/friend-details.component';

@NgModule({
  declarations: [
    FriendsComponent,
    FriendRequestsComponent,
    FriendDetailsComponent
  ],
  imports: [
    CommonModule,
    FriendsRoutingModule,
    SharedModule,
    FormsModule,
    ReactiveFormsModule
  ]
})
export class FriendsModule { }
