import { Component, OnInit } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { map, switchMap, zip } from 'rxjs';
import { Profile, SupabaseService } from 'src/app/core/supabase.service';
import { UsersService } from 'src/app/modules/shared/services/users.service';
import { SendFriendRequest } from '../../models/send-friend-request.model';
import { FriendsService } from '../../services/friends.service';
import { MatDialog } from '@angular/material/dialog';
import { FriendRequestsComponent } from '../friend-requests/friend-requests.component';
import { FriendRequest } from '../../models/friend-request.model';
import { maxUsernameLength, minUsernameLength } from 'src/app/modules/shared/consts/username-config.const';
import { FriendDetailsComponent } from '../../components/friend-details/friend-details.component';
import { MatSnackBar } from '@angular/material/snack-bar';
import { FriendErrors } from 'src/app/core/errors/friends.const';

@Component({
  selector: 'app-friends',
  templateUrl: './friends.component.html',
  styleUrls: ['./friends.component.scss']
})
export class FriendsComponent implements OnInit {

  constructor(private readonly formBuilder: FormBuilder,
    private readonly supabase: SupabaseService,
    private readonly friendService: FriendsService,
    private readonly userService: UsersService,
    private readonly dialog: MatDialog,
    private readonly _snackBar: MatSnackBar
  ) {}

  loading = false
  minUsernameLength = minUsernameLength
  maxUsernameLength = maxUsernameLength
  showForm: boolean = false
  friends: Array<Profile>  
  requests: Array<FriendRequest>
  form: FormGroup

  ngOnInit(): void {
    this.createForm()
    this.fetchUserFriends()
    this.fetchUserFriendRequests()
  }

  createForm(): void {
    this.form = this.formBuilder.group({
      username: ['', [
        Validators.required,
        Validators.minLength(this.minUsernameLength), 
        Validators.maxLength(this.maxUsernameLength)]
      ]
    })
  }

  sendFriendRequest(): void {
    const friendUsername = this.form.value.username
    zip([
      this.supabase.session,
      this.userService.getUserByUsername(friendUsername)
    ]).pipe(
      map(([_, friend]) => {
        if (!friend.length) {
          throw new Error('The user does not exist')
        }
        return [_, friend] 
      }),
      map(([session, friend])=> [session!.user.id, friend[0].id]),
      switchMap(([userId, friendId]) => {
        const groupData = new SendFriendRequest(
          userId,
          friendId
        );
        return this.friendService.sendFriendRequest(groupData)
      })
    ).subscribe({
      next: () => {
        this.openSnackBar('Richiesta di amicizia inviata', '👍')
      },
      error: (error) => {
        switch(error.message) {
          case FriendErrors.NOT_EXIST:
            this.openSnackBar('Utente non trovato', '😵')
            break;
          default:
            this.openSnackBar('Si è verificato un errore', '😵')
            break;
        }
      }
    });
  }

  private fetchUserFriends(): void {
    this.loading = true
    this.supabase.session.pipe(
      map(session => session!.user),
      switchMap(user => {
        return this.friendService.getUserFriends(user.id)
      })
    ).subscribe({
      next: (data) => {
        this.loading = false
        this.friends = data!
      }
    })
  }

  private fetchUserFriendRequests(): void {
    this.supabase.session.pipe(
      map(session => session!.user),
      switchMap(user => {
        return this.friendService.getUserFriendRequests(user.id)
      })
    ).subscribe( data => this.requests = data!)
  }

  openDialog(): void {
    const dialogRef = this.dialog.open(FriendRequestsComponent, {
      width: '90vw', maxWidth: '90vw',
      data: { requests: this.requests}
    });
  
    dialogRef.afterClosed().subscribe((reloadRequests: boolean) => {
      if (reloadRequests) {
        this.fetchUserFriends()
        this.fetchUserFriendRequests()
      }
    });
  }

  openFriendDetail(friend: Profile): void {
    const dialogRef = this.dialog.open(FriendDetailsComponent, {
      width: '90vw', maxWidth: '90vw',
      data: { 
        friend: friend
      }
    });
  
    dialogRef.afterClosed().subscribe((reload: boolean) => {
      if (reload) {
        this.fetchUserFriends()
        this.fetchUserFriendRequests()
      }
    });
  }

  openSnackBar(message: string, action: string) {
    this._snackBar.open(message, action, {
      duration: 5000,
      horizontalPosition: 'center',
      verticalPosition: 'top'
    });
  }
}
