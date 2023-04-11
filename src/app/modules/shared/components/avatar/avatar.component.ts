import { Component, EventEmitter, Input, Output } from '@angular/core'
import { SafeResourceUrl, DomSanitizer } from '@angular/platform-browser'
import { SupabaseService } from 'src/app/core/supabase.service'

@Component({
  selector: 'app-avatar',
  templateUrl: './avatar.component.html',
  styleUrls: ['./avatar.component.scss'],
})
export class AvatarComponent {
  _avatarUrl: SafeResourceUrl | undefined
  uploading = false

  @Input()
  hideUpload: boolean = false

  @Input()
  set avatarUrl(url: string | null) {
    if (url) {
      this.downloadImage(url)
    }
  }

  @Output() 
  upload = new EventEmitter<string>()

  constructor(private readonly supabase: SupabaseService, private readonly dom: DomSanitizer) {}

  downloadImage(path: string) {

    this.supabase.downLoadImage(path).subscribe({
      next: (data) => {
        if (data instanceof Blob) {
          this._avatarUrl = this.dom.bypassSecurityTrustResourceUrl(URL.createObjectURL(data))
        }
      }, 
      error: () => {

      }
    })
  }

  uploadAvatar(event: any) {
    console.log(event)
    this.uploading = true
    if (!event.target.files || event.target.files.length === 0) {
      throw new Error('You must select an image to upload.')
    }
    const file = event.target.files[0]
    const fileExt = file.name.split('.').pop()
    const filePath = `${Math.random()}.${fileExt}`
    this.supabase.uploadAvatar(filePath, file).subscribe({
      next: () => {
        this.upload.emit(filePath)
        this.uploading = false
      }, 
      error: (error) => {
        alert(error.message)
        this.uploading = false
        throw error
      }
    })
  }
}