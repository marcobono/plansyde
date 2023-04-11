import { Component, OnInit } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { MatSnackBar } from '@angular/material/snack-bar';
import { SupabaseService } from 'src/app/core/supabase.service';

@Component({
  selector: 'app-login',
  templateUrl: './login.component.html',
  styleUrls: ['./login.component.scss']
})
export class LoginComponent implements OnInit {
  loading = false

  form: FormGroup

  constructor(
    private readonly supabase: SupabaseService,
    private readonly formBuilder: FormBuilder,
    private readonly _snackBar: MatSnackBar
  ) {}

  ngOnInit(): void {
    this.createForm()
  }

  private createForm(): void {
    this.form = this.formBuilder.group({
      email: [null, [Validators.email, Validators.required]]
    })
  }

  onSubmit(): void {
    if (this.form.valid) {
      this.loading = true
      const email = this.form.value.email! as string
      this.supabase.signIn(email).subscribe({
        next: () => {
          this.loading = false
          this.openSnackBar()
          this.form.reset()
        },
        error: (error) => {
          this.loading = false
          throw error
        }
      })
    }
  }

  openSnackBar() {
    this._snackBar.open('Continua tramite il link che ti è arrivato per mail', '👍', {
      duration: 5000,
      horizontalPosition: 'center',
      verticalPosition: 'top'
    });
  }
}
