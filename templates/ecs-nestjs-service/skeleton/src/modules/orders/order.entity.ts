import { Column, CreateDateColumn, Entity, PrimaryGeneratedColumn } from 'typeorm';

@Entity({ name: 'orders' })
export class Order {
  @PrimaryGeneratedColumn('uuid') id: string;
  @Column({ name: 'product_id', type: 'uuid' }) productId: string; // id only: no cross-module DB relation
  @Column({ type: 'integer' }) quantity: number;
  @Column({ name: 'total_cents', type: 'integer' }) totalCents: number;
  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' }) createdAt: Date;
}
