import { Component, Input, OnInit } from '@angular/core'
import { FormBuilder, Validators } from '@angular/forms'
import { MatSnackBar } from '@angular/material/snack-bar'
import { Router } from '@angular/router'
import { User } from '@supabase/supabase-js'
import { switchMap} from 'rxjs'
import { Profile, SupabaseService } from 'src/app/core/supabase.service'

@Component({
  selector: 'app-account',
  templateUrl: './account.component.html',
  styleUrls: ['./account.component.scss'],
})
export class AccountComponent implements OnInit {
  loading = false
  profile: Profile
  user: User
  minUsernameLength = 3
  maxUsernameLength = 20

  form = this.formBuilder.group({
    username: ['', [
      Validators.minLength(this.minUsernameLength), 
      Validators.maxLength(this.maxUsernameLength),
      Validators.pattern(/^[a-z0-9._]+$/)
    ]],
    avatar_url: '',
    full_name: ''
  })

  constructor(private readonly supabase: SupabaseService, 
    private readonly formBuilder: FormBuilder,
    private readonly router: Router,
    private readonly _snackBar: MatSnackBar
  ) {}

  ngOnInit(): void {
    this.getProfile()
  }

  getProfile() {
    this.loading = true
    this.supabase.session.pipe(
      switchMap((session) => {
        const {user} = session!
        this.user = user
        return this.supabase.profile(user)}),
    ).subscribe({
      next: (data) => {
        if(data) {
          this.profile = data
          const { username, website, avatar_url, full_name } = this.profile
          this.form.patchValue({
            username,
            avatar_url,
            full_name
          })
          this.loading = false
        }
      },
      error: (error) => {
        this.loading = false
        throw error
      }
    })
  }

  updateProfile(): void {
    this.loading = true
    const {username, avatar_url, full_name} = this.form.value 

    this.supabase.session.pipe(
      switchMap((session) => {
        const { user } = session!
        const updateRequest = {
          id: user.id,
          username,
          avatar_url,
          full_name
        }
        return this.supabase.updateProfile(updateRequest)
      })
    ).subscribe({
      next: () => {
        this.loading = false
        this.openSnackBar('Profilo aggiornato', '👍')
        this.getProfile()
      },
      error: (error) => {
        this.openSnackBar('Si è verificato un errore', '😵')
        this.loading = false
        throw error
      }
    })
  }

  signOut() {
    this.supabase.signOut().subscribe({
      next: () => {
        this.router.navigateByUrl('/login')
      }
    })
  }

  get avatarUrl() {
    return this.form.value.avatar_url as string
  }

  updateAvatar(event: string): void {
    this.form.patchValue({
      avatar_url: event,
    })
    this.updateProfile()
  }

  hasPatternError(formControlName: string): boolean {
    const control = this.form.get(formControlName)
    if (!!control) {
      return !!control.errors && !!control.errors['pattern']
    }
    return false
  }

  openSnackBar(message: string, action: string) {
    this._snackBar.open(message, action, {
      duration: 5000,
      horizontalPosition: 'center',
      verticalPosition: 'top'
    });
  }
}