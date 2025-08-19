import { Injectable } from '@nestjs/common';
import { diskStorage } from 'multer';
import { extname } from 'path';
import { v4 as uuidv4 } from 'uuid';
import { promises as fs } from 'fs';
import { join } from 'path';

// Type for multer file
interface MulterFile {
  fieldname: string;
  originalname: string;
  encoding: string;
  mimetype: string;
  size: number;
  destination: string;
  filename: string;
  path: string;
  buffer: Buffer;
}

@Injectable()
export class FileUploadService {
  private uploadPath = 'uploads/';

  getMulterConfig() {
    return {
      storage: diskStorage({
        destination: (
          req: any,
          file: MulterFile,
          cb: (error: Error | null, destination: string) => void,
        ) => {
          // Ensure uploads directory exists
          fs.mkdir(this.uploadPath, { recursive: true })
            .then(() => cb(null, this.uploadPath))
            .catch((error) => cb(error, this.uploadPath));
        },
        filename: (
          req: any,
          file: MulterFile,
          cb: (error: Error | null, filename: string) => void,
        ) => {
          // Generate unique filename with original extension
          const uniqueName = `${uuidv4()}${extname(file.originalname || '')}`;
          cb(null, uniqueName);
        },
      }),
      fileFilter: (
        req: any,
        file: MulterFile,
        cb: (error: Error | null, acceptFile: boolean) => void,
      ) => {
        // Accept only image files
        if (
          file.mimetype &&
          file.mimetype.match(/\/(jpg|jpeg|png|gif|webp)$/)
        ) {
          cb(null, true);
        } else {
          cb(new Error('Only image files are allowed!'), false);
        }
      },
      limits: {
        fileSize: 10 * 1024 * 1024, // 10MB limit for production
      },
    };
  }

  getFileUrl(filename: string): string {
    const baseUrl = process.env.BASE_URL || process.env.NGINX_BASE_URL || 'http://localhost:3000';
    return `${baseUrl}/uploads/${filename}`;
  }

  async deleteFile(filename: string): Promise<void> {
    try {
      const filePath = join(this.uploadPath, filename);
      await fs.unlink(filePath);
      console.log(`✅ File deleted: ${filename}`);
    } catch (error) {
      console.error('❌ Error deleting file:', error);
      throw new Error(`Failed to delete file: ${filename}`);
    }
  }

  async fileExists(filename: string): Promise<boolean> {
    try {
      const filePath = join(this.uploadPath, filename);
      await fs.access(filePath);
      return true;
    } catch {
      return false;
    }
  }

  getUploadPath(): string {
    return this.uploadPath;
  }
}
